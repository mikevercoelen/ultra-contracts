// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./base/UltrareumERC721.sol";
import "./interfaces/IERC721AuctionHouse.sol";
import "./interfaces/IWETH.sol";

/**
 * @title An open auction house, enabling collectors to run their own auctions
 */
contract ERC721AuctionHouse is IERC721AuctionHouse, Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using Counters for Counters.Counter;

  // The minimum percentage difference between the last bid amount and the current bid.
  uint8 public minBidIncrementPercentage;

  // The service wallet info
  uint256 private serviceCut;
  uint256 private initialCut;
  bool private nativeUsed;

  // / The address of the WETH contract, so that any ETH transferred can be handled as an ERC-20
  address public wethAddress;

  // A mapping of all of the auctions currently running.
  mapping(uint256 => IERC721AuctionHouse.Auction) public auctions;

  bytes4 constant interfaceId = 0x80ac58cd; // 721 interface id
  uint private constant BP_DIVISOR = 10000;

  Counters.Counter private _auctionIdTracker;

  /**
   * @notice Require that the specified auction exists
   */
  modifier auctionExists(uint256 auctionId) {
    require(_exists(auctionId), "Auction doesn't exist");
    _;
  }

  /**
   * @notice Require that currency should be allowed
   */
  modifier currencyAllowed(address currency) {
    require(
      (currency == address(0) && nativeUsed) || currency == wethAddress,
      "Not allowed currency"
    );
    _;
  }

  /*
   * Constructor
   */
  constructor(
    uint256 _serviceCut,
    uint256 _initialCut,
    address _weth,
    bool _nativeUsed
  ) {
    require(_serviceCut > 0, "Zero service fee");
    require(_serviceCut < BP_DIVISOR, "Invalid service fee");

    serviceCut = _serviceCut;
    initialCut = _initialCut;
    wethAddress = _weth;
    nativeUsed = _nativeUsed;
    minBidIncrementPercentage = 5; // 5%
  }

  function setServiceCut(uint256 _cut) public onlyOwner {
    serviceCut = _cut;
  }

  function getServiceCut() public view onlyOwner returns (uint256) {
    return serviceCut;
  }

  function setInitialCut(uint256 _cut) public onlyOwner {
    initialCut = _cut;
  }

  function getInitialCut() public view onlyOwner returns (uint256) {
    return initialCut;
  }

  /**
   * @notice Create an auction.
   * @dev Store the auction details in the auctions mapping and emit an AuctionCreated event.
   */
  function createAuction(
    uint256 tokenId,
    address tokenContract,
    uint256 startDate,
    uint256 endDate,
    uint256 reservePrice,
    uint256 instantBuyPrice,
    address auctionCurrency
  )
    public
    override
    nonReentrant
    currencyAllowed(auctionCurrency)
    returns (uint256)
  {
    require(
      IERC165(tokenContract).supportsInterface(interfaceId),
      "tokenContract does not support ERC721 interface"
    );

    address tokenOwner = UltrareumERC721(tokenContract).ownerOf(tokenId);
    require(
      msg.sender == UltrareumERC721(tokenContract).getApproved(tokenId) ||
        msg.sender == tokenOwner,
      "Caller must be approved or owner for token id"
    );
    uint256 auctionId = _auctionIdTracker.current();

    auctions[auctionId] = Auction({
      tokenId: tokenId,
      tokenContract: tokenContract,
      amount: 0,
      startDate: startDate,
      endDate: endDate,
      firstBidTime: 0,
      reservePrice: reservePrice,
      instantBuyPrice: instantBuyPrice,
      tokenOwner: tokenOwner,
      bidder: payable(0),
      auctionCurrency: auctionCurrency
    });

    UltrareumERC721(tokenContract).transferFrom(
      tokenOwner,
      address(this),
      tokenId
    );

    _auctionIdTracker.increment();

    emit AuctionCreated(
      block.timestamp,
      auctionId,
      tokenId,
      tokenContract,
      startDate,
      endDate,
      reservePrice,
      instantBuyPrice,
      tokenOwner,
      auctionCurrency
    );

    return auctionId;
  }

  function setAuctionReservePrice(uint256 auctionId, uint256 reservePrice)
    external
    override
    auctionExists(auctionId)
  {
    require(
      msg.sender == auctions[auctionId].tokenOwner,
      "Must be token owner"
    );
    require(
      auctions[auctionId].firstBidTime == 0,
      "Auction has already started"
    );

    auctions[auctionId].reservePrice = reservePrice;

    emit AuctionReservePriceUpdated(
      block.timestamp,
      auctionId,
      auctions[auctionId].tokenId,
      auctions[auctionId].tokenContract,
      reservePrice
    );
  }

  /**
   * @notice Create a bid on a token, with a given amount.
   * @dev If provided a valid bid, transfers the provided amount to this contract.
   * If the auction is run in native ETH, the ETH is wrapped so it can be identically to other
   * auction currencies in this contract.
   */
  function createBid(uint256 auctionId, uint256 amount)
    external
    payable
    override
    auctionExists(auctionId)
    nonReentrant
  {
    address payable lastBidder = auctions[auctionId].bidder;

    require(block.timestamp >= auctions[auctionId].startDate, "Not started");

    require(block.timestamp < auctions[auctionId].endDate, "Expired");

    require(
      amount >= auctions[auctionId].reservePrice,
      "Must send at least reservePrice"
    );

    require(
      amount >=
        auctions[auctionId].amount.add(
          auctions[auctionId].amount.mul(minBidIncrementPercentage).div(100)
        ),
      "Must send more than last bid by minBidIncrementPercentage amount"
    );

    // If this is the first valid bid, we should set the starting time now.
    // If it's not, then we should refund the last bidder
    if (auctions[auctionId].firstBidTime == 0) {
      auctions[auctionId].firstBidTime = block.timestamp;
    } else if (lastBidder != address(0)) {
      _handleOutgoingBid(
        lastBidder,
        auctions[auctionId].amount,
        auctions[auctionId].auctionCurrency
      );
    }

    _handleIncomingBid(amount, auctions[auctionId].auctionCurrency);

    auctions[auctionId].amount = amount;
    auctions[auctionId].bidder = payable(msg.sender);

    emit AuctionBid(
      block.timestamp,
      auctionId,
      auctions[auctionId].tokenId,
      auctions[auctionId].tokenContract,
      msg.sender,
      amount,
      lastBidder == address(0) // firstBid boolean
    );
  }

  function instantBuy(uint256 auctionId, uint256 amount)
    external
    payable
    override
    auctionExists(auctionId)
    nonReentrant
  {
    require(
      uint256(auctions[auctionId].instantBuyPrice) == amount,
      "Invalid amount"
    );

    // TODO: double check with business requirements, this won't allow for instantBuy after a first bid has come in
    require(auctions[auctionId].firstBidTime == 0, "Already has bids");

    address currency =
      auctions[auctionId].auctionCurrency == address(0)
        ? wethAddress
        : auctions[auctionId].auctionCurrency;

    uint256 serviceFee = 0;
    uint256 mintFee = 0;
    address serviceWallet = this.owner();

    uint256 tokenOwnerProfit = auctions[auctionId].instantBuyPrice;

    try
      UltrareumERC721(auctions[auctionId].tokenContract).safeTransferFrom(
        address(this),
        msg.sender,
        auctions[auctionId].tokenId
      )
    {} catch {
      // TODO: SUPER IMPORTANT, this needs to be double double checked, is this correct?
      _handleOutgoingBid(
        msg.sender,
        amount,
        auctions[auctionId].auctionCurrency
      );

      // TODO: SUPER IMPORTANT, this needs to be double double checked, why do we need it?
      _cancelAuction(auctionId);
      return;
    }

    if (serviceWallet != address(0)) {
      address minterWallet;
      uint256 royaltyFee;
      bytes memory royaltyData;

      serviceFee = tokenOwnerProfit.mul(serviceCut).div(BP_DIVISOR);

      (minterWallet, royaltyFee, royaltyData) = UltrareumERC721(
        auctions[auctionId]
          .tokenContract
      )
        .royaltyInfo(auctions[auctionId].tokenId, tokenOwnerProfit, "");

      mintFee = minterWallet == auctions[auctionId].tokenOwner
        ? tokenOwnerProfit.mul(initialCut).div(BP_DIVISOR)
        : royaltyFee;

      tokenOwnerProfit = tokenOwnerProfit.sub(serviceFee).sub(mintFee);

      _handleOutgoingBid(
        serviceWallet,
        serviceFee,
        auctions[auctionId].auctionCurrency
      );

      _handleOutgoingBid(
        minterWallet,
        mintFee,
        auctions[auctionId].auctionCurrency
      );
    }

    _handleOutgoingBid(
      auctions[auctionId].tokenOwner,
      tokenOwnerProfit,
      auctions[auctionId].auctionCurrency
    );

    emit AuctionEnded(
      block.timestamp,
      auctionId,
      auctions[auctionId].tokenId,
      auctions[auctionId].tokenContract,
      auctions[auctionId].tokenOwner,
      auctions[auctionId].bidder,
      tokenOwnerProfit,
      currency,
      true
    );

    delete auctions[auctionId];
  }

  /**
   * @dev If for some reason the auction cannot be finalized (invalid token recipient, for example),
   * The auction is reset and the NFT is transferred back to the auction creator.
   */
  function endAuction(uint256 auctionId)
    external
    override
    auctionExists(auctionId)
    nonReentrant
  {
    require(
      uint256(auctions[auctionId].firstBidTime) != 0,
      "Auction hasn't begun"
    );

    require(
      block.timestamp >= auctions[auctionId].endDate,
      "Auction hasn't completed"
    );

    address currency =
      auctions[auctionId].auctionCurrency == address(0)
        ? wethAddress
        : auctions[auctionId].auctionCurrency;

    uint256 serviceFee = 0;
    uint256 mintFee = 0;
    address serviceWallet = this.owner();

    uint256 tokenOwnerProfit = auctions[auctionId].amount;

    // Otherwise, transfer the token to the winner and pay out the participants below
    try
      UltrareumERC721(auctions[auctionId].tokenContract).safeTransferFrom(
        address(this),
        auctions[auctionId].bidder,
        auctions[auctionId].tokenId
      )
    {} catch {
      _handleOutgoingBid(
        auctions[auctionId].bidder,
        auctions[auctionId].amount,
        auctions[auctionId].auctionCurrency
      );
      _cancelAuction(auctionId);
      return;
    }

    if (serviceWallet != address(0)) {
      address minterWallet;
      uint256 royaltyFee;
      bytes memory royaltyData;

      serviceFee = tokenOwnerProfit.mul(serviceCut).div(BP_DIVISOR);
      (minterWallet, royaltyFee, royaltyData) = UltrareumERC721(
        auctions[auctionId]
          .tokenContract
      )
        .royaltyInfo(auctions[auctionId].tokenId, tokenOwnerProfit, "");
      mintFee = minterWallet == auctions[auctionId].tokenOwner
        ? tokenOwnerProfit.mul(initialCut).div(BP_DIVISOR)
        : royaltyFee;
      tokenOwnerProfit = tokenOwnerProfit.sub(serviceFee).sub(mintFee);
      _handleOutgoingBid(
        serviceWallet,
        serviceFee,
        auctions[auctionId].auctionCurrency
      );
      _handleOutgoingBid(
        minterWallet,
        mintFee,
        auctions[auctionId].auctionCurrency
      );
    }
    _handleOutgoingBid(
      auctions[auctionId].tokenOwner,
      tokenOwnerProfit,
      auctions[auctionId].auctionCurrency
    );

    emit AuctionEnded(
      block.timestamp,
      auctionId,
      auctions[auctionId].tokenId,
      auctions[auctionId].tokenContract,
      auctions[auctionId].tokenOwner,
      auctions[auctionId].bidder,
      tokenOwnerProfit,
      currency,
      false
    );

    delete auctions[auctionId];
  }

  /**
   * @notice Cancel an auction.
   * @dev Transfers the NFT back to the auction creator and emits an AuctionCanceled event
   */
  function cancelAuction(uint256 auctionId)
    external
    override
    nonReentrant
    auctionExists(auctionId)
  {
    require(
      auctions[auctionId].tokenOwner == msg.sender,
      "Can only be called by auction creator"
    );
    require(
      uint256(auctions[auctionId].firstBidTime) == 0,
      "Can't cancel an auction once it's begun"
    );
    _cancelAuction(auctionId);
  }

  /**
   * @dev Given an amount and a currency, transfer the currency to this contract.
   * If the currency is ETH (0x0), attempt to wrap the amount as WETH
   */
  function _handleIncomingBid(uint256 amount, address currency) internal {
    // If this is an ETH bid, ensure they sent enough and convert it to WETH under the hood
    if (currency == address(0) && nativeUsed) {
      require(
        msg.value == amount,
        "Sent ETH Value does not match specified bid amount"
      );
      IWETH(wethAddress).deposit{value: amount}();
    } else {
      // We must check the balance that was actually transferred to the auction,
      // as some tokens impose a transfer fee and would not actually transfer the
      // full amount to the market, resulting in potentally locked funds
      IERC20 token = IERC20(currency);
      uint256 beforeBalance = token.balanceOf(address(this));
      token.safeTransferFrom(msg.sender, address(this), amount);
      uint256 afterBalance = token.balanceOf(address(this));
      require(
        beforeBalance.add(amount) == afterBalance,
        "Token transfer call did not transfer expected amount"
      );
    }
  }

  function _handleOutgoingBid(
    address to,
    uint256 amount,
    address currency
  ) internal {
    // If the auction is in ETH, unwrap it from its underlying WETH and try to send it to the recipient.
    if (currency == address(0) && nativeUsed) {
      IWETH(wethAddress).withdraw(amount);

      // If the ETH transfer fails (sigh), rewrap the ETH and try send it as WETH.
      if (!_safeTransferETH(to, amount)) {
        IWETH(wethAddress).deposit{value: amount}();
        IERC20(wethAddress).safeTransfer(to, amount);
      }
    } else {
      IERC20(currency).safeTransfer(to, amount);
    }
  }

  function _safeTransferETH(address to, uint256 value) internal returns (bool) {
    (bool success, ) = to.call{value: value}(new bytes(0));
    return success;
  }

  function _cancelAuction(uint256 auctionId) internal {
    address tokenOwner = auctions[auctionId].tokenOwner;
    UltrareumERC721(auctions[auctionId].tokenContract).safeTransferFrom(
      address(this),
      tokenOwner,
      auctions[auctionId].tokenId
    );

    emit AuctionCanceled(
      block.timestamp,
      auctionId,
      auctions[auctionId].tokenId,
      auctions[auctionId].tokenContract,
      tokenOwner
    );
    delete auctions[auctionId];
  }

  function _exists(uint256 auctionId) internal view returns (bool) {
    return auctions[auctionId].tokenOwner != address(0);
  }

  // TODO: consider reverting if the message sender is not WETH
  receive() external payable {}

  fallback() external payable {}
}
