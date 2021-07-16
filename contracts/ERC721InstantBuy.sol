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
  bool private nativeUsed;

  // / The address of the WETH contract, so that any ETH transferred can be handled as an ERC-20
  address public wethAddress;

  // A mapping of all of the instant buys currently running
  mapping(uint256 => IERC721InstantBuy.InstantBuy) public instantBuys;

  bytes4 constant interfaceId = 0x80ac58cd; // 721 interface id
  uint private constant BP_DIVISOR = 10000;

  Counters.Counter private _instantBuysIdTracker;

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

  constructor(
    uint256 _serviceCut,
    address _weth,
    bool _nativeUsed
  ) {
    require(_serviceCut > 0, "Zero service fee");
    require(_serviceCut < BP_DIVISOR, "Invalid service fee");

    serviceCut = _serviceCut;
    wethAddress = _weth;
    nativeUsed = _nativeUsed;
    minBidIncrementPercentage = 5;
  }

  function setServiceCut(uint256 _cut) public onlyOwner {
    serviceCut = _cut;
  }

  function getServiceCut() public view onlyOwner returns (uint256) {
    return serviceCut;
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

  // TODO: setInstantBuyPrice

  function instantBuy(uint256 instantBuyId, uint256 amount)
    external
    payable
    override
    instantBuyExists(instantBuyId)
    nonReentrant
  {
    require(uint256(instantBuys[instantBuyId].price) != 0, "Not for sale");

    require(
      uint256(instantBuys[instantBuyId].price) == amount,
      "Invalid amount"
    );

    address currency =
      instantBuys[instantBuyId].instantBuyCurrency == address(0)
        ? wethAddress
        : instantBuys[instantBuyId].instantBuyCurrency;

    uint256 serviceFee = 0;
    address serviceWallet = this.owner();
    uint256 tokenOwnerProfit = instantBuys[instantBuyId].price;

    // Transfer the token
    UltrareumERC721(instantBuyId[instantBuyId].tokenContract).safeTransferFrom(
      address(this),
      instantBuys[instantBuyId].tokenOwner,
      msg.sender
    );

    // TODO: Payout the service
    // TODO: Payout the seller
  }

  // TODO: consider reverting if the message sender is not WETH
  receive() external payable {}

  fallback() external payable {}
}
