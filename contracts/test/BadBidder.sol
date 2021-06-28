// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interfaces/IERC721AuctionHouse.sol";

// This contract is meant to mimic a bidding contract that does not implement on IERC721 Received,
// and thus should cause a revert when an auction is finalized with this as the winning bidder.
contract BadBidder {
  address private auction;

  constructor(address _auction) {
    auction = _auction;
  }

  function placeBid(uint256 auctionId, uint256 amount) external payable {
    IERC721AuctionHouse(auction).createBid{value: amount}(auctionId, amount);
  }

  receive() external payable {}

  fallback() external payable {}
}
