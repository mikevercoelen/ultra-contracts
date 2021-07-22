// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/**
 * @title Interface for Instant Buy logic
 */
interface IERC721InstantBuy {
  struct InstantBuy {
    // ID for the ERC721 token
    uint256 tokenId;
    // Address for the ERC721 contract
    address tokenContract;
    // The minimum price of the first bid
    uint256 price;
    // The address that should receive the funds once the NFT is sold.
    address tokenOwner;
    // The address of the ERC-20 currency to run the auction with.
    // If set to 0x0, the auction will be run in ETH
    address instantBuyCurrency;
  }

  event InstantBuyCreated(
    uint256 timestamp,
    uint256 indexed instantBuyId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    uint256 price,
    address tokenOwner,
    address instantBuyCurrency
  );

  event InstantBuyEnded(
    uint256 timestamp,
    uint256 indexed instantBuyId,
    uint256 indexed tokenId,
    address indexed tokenContract,
    address tokenOwner,
    address buyer,
    uint256 amount,
    address instantBuyCurrency
  );

  function createInstantBuy(
    uint256 tokenId,
    address tokenContract,
    uint256 price,
    address instantBuyCurrency
  ) external returns (uint256);

  function instantBuy(uint256 instantBuyId, uint256 amount) external payable;
}
