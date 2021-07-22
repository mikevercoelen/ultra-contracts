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
import "./interfaces/IERC721InstantBuy.sol";
import "./interfaces/IWETH.sol";

/**
 * @title An instant buy / sell setup for ERC721's
 */
contract ERC721InstantBuy is IERC721InstantBuy, Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using Counters for Counters.Counter;

  // The service wallet info
  uint256 private serviceCut;
  uint256 private initialCut;
  bool private nativeUsed;

  // / The address of the WETH contract, so that any ETH transferred can be handled as an ERC-20
  address public wethAddress;

  // A mapping of all of the instant buys currently running
  mapping(uint256 => IERC721InstantBuy.InstantBuy) public instantBuys;

  bytes4 constant interfaceId = 0x80ac58cd; // 721 interface id
  uint private constant BP_DIVISOR = 10000;

  Counters.Counter private _instantBuysIdTracker;

  modifier instantBuyExists(uint256 instantBuyId) {
    require(_exists(instantBuyId), "Instant buy doesn't exist");
    _;
  }

  modifier currencyAllowed(address currency) {
    require(
      (currency == address(0) && nativeUsed) || currency == wethAddress,
      "Not allowed currency"
    );
    _;
  }

  constructor(
    uint256 _serviceCut,
    address _weth,
    uint256 _initialCut,
    bool _nativeUsed
  ) {
    require(_serviceCut > 0, "Zero service fee");
    require(_serviceCut < BP_DIVISOR, "Invalid service fee");

    serviceCut = _serviceCut;
    wethAddress = _weth;
    initialCut = _initialCut;
    nativeUsed = _nativeUsed;
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

  function createInstantBuy(
    uint256 tokenId,
    address tokenContract,
    uint256 price,
    address instantBuyCurrency
  )
    public
    override
    nonReentrant
    currencyAllowed(instantBuyCurrency)
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

    uint256 instantBuyId = _instantBuysIdTracker.current();

    instantBuys[instantBuyId] = InstantBuy({
      tokenId: tokenId,
      tokenContract: tokenContract,
      price: price,
      tokenOwner: tokenOwner,
      instantBuyCurrency: instantBuyCurrency
    });

    UltrareumERC721(tokenContract).transferFrom(
      tokenOwner,
      address(this),
      tokenId
    );

    _instantBuysIdTracker.increment();

    emit InstantBuyCreated(
      block.timestamp,
      instantBuyId,
      tokenId,
      tokenContract,
      price,
      tokenOwner,
      instantBuyCurrency
    );

    return instantBuyId;
  }

  function instantBuy(uint256 instantBuyId, uint256 amount)
    external
    payable
    override
    instantBuyExists(instantBuyId)
    nonReentrant
  {
    require(
      uint256(instantBuys[instantBuyId].price) == amount,
      "Invalid amount"
    );

    address currency =
      instantBuys[instantBuyId].instantBuyCurrency == address(0)
        ? wethAddress
        : instantBuys[instantBuyId].instantBuyCurrency;

    address serviceWallet = this.owner();
    uint256 tokenOwnerProfit = instantBuys[instantBuyId].price;
    uint256 serviceFee = 0;
    uint256 mintFee = 0;

    // Transfer the token
    UltrareumERC721(instantBuys[instantBuyId].tokenContract).safeTransferFrom(
      address(this),
      msg.sender,
      instantBuys[instantBuyId].tokenId
    );

    if (serviceWallet != address(0)) {
      address minterWallet;
      uint256 royaltyFee;
      bytes memory royaltyData;

      serviceFee = tokenOwnerProfit.mul(serviceCut).div(BP_DIVISOR);

      (minterWallet, royaltyFee, royaltyData) = UltrareumERC721(
        instantBuys[instantBuyId]
          .tokenContract
      )
        .royaltyInfo(instantBuys[instantBuyId].tokenId, tokenOwnerProfit, "");

      uint256 mintFee =
        minterWallet == instantBuys[instantBuyId].tokenOwner
          ? tokenOwnerProfit.mul(initialCut).div(BP_DIVISOR)
          : royaltyFee;

      tokenOwnerProfit = tokenOwnerProfit.sub(serviceFee).sub(mintFee);

      address instantBuyCurrency = instantBuys[instantBuyId].instantBuyCurrency;

      // Pay the service
      _handleOutgoingTransfer(serviceWallet, serviceFee, instantBuyCurrency);

      // Pay the minter
      _handleOutgoingTransfer(minterWallet, mintFee, instantBuyCurrency);
    }

    // Pay the seller
    _handleOutgoingTransfer(
      instantBuys[instantBuyId].tokenOwner,
      tokenOwnerProfit,
      instantBuys[instantBuyId].instantBuyCurrency
    );

    emit InstantBuyEnded(
      block.timestamp,
      instantBuyId,
      instantBuys[instantBuyId].tokenId,
      instantBuys[instantBuyId].tokenContract,
      instantBuys[instantBuyId].tokenOwner,
      msg.sender,
      tokenOwnerProfit,
      currency
    );

    delete instantBuys[instantBuyId];
  }

  function _handleOutgoingTransfer(
    address to,
    uint256 amount,
    address currency
  ) internal {
    // If the instant buy is in ETH, unwrap it from its underlying WETH and try to send it to the recipient.
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

  function _exists(uint256 instantBuyId) internal view returns (bool) {
    return instantBuys[instantBuyId].tokenOwner != address(0);
  }

  // TODO: consider reverting if the message sender is not WETH
  receive() external payable {}

  fallback() external payable {}
}
