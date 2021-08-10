// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/**
 * @title Interface for Auction Houses
 */
interface IERC721AuctionHouse {
  struct Auction {
    // ID for the ERC721 token
    uint256 tokenId;
    // Address for the ERC721 contract
    address tokenContract;
    // The current highest bid amount
    uint256 amount;
    uint256 startDate;
    uint256 endDate;
    // The time of the first bid
    uint256 firstBidTime;
    // The minimum price of the first bid
    uint256 reservePrice;
    // The price for an instant buy
    uint256 instantBuyPrice;
    // The address that should receive the funds once the NFT is sold.
    address tokenOwner;
    // The address of the current highest bid
    address payable bidder;
    // The address of the ERC-20 currency to run the auction with.
    // If set to 0x0, the auction will be run in ETH
    address auctionCurrency;
  }

  event AuctionCreated(
    uint256 timestamp,
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    uint256 startDate,
    uint256 endDate,
    uint256 reservePrice,
    uint256 instantBuyPrice,
    address tokenOwner,
    address auctionCurrency
  );

  event AuctionReservePriceUpdated(
    uint256 timestamp,
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    uint256 reservePrice
  );

  event AuctionBid(
    uint256 timestamp,
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    address sender,
    uint256 value,
    bool firstBid
  );

  event AuctionEnded(
    uint256 timestamp,
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    address tokenOwner,
    address winner,
    uint256 amount,
    address auctionCurrency,
    bool instantBought
  );

  event AuctionCanceled(
    uint256 timestamp,
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    address tokenOwner
  );

  function createAuction(
    uint256 tokenId,
    address tokenContract,
    uint256 startDate,
    uint256 endDate,
    uint256 reservePrice,
    uint256 instantBuyPrice,
    address auctionCurrency
  ) external returns (uint256);

  function setAuctionReservePrice(uint256 auctionId, uint256 reservePrice)
    external;

  function createBid(uint256 auctionId, uint256 amount) external payable;

  function instantBuy(uint256 auctionId, uint256 amount) external payable;

  function endAuction(uint256 auctionId) external;

  function cancelAuction(uint256 auctionId) external;
}
