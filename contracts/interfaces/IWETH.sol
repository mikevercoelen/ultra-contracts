// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IWETH {
  function deposit() external payable;

  function withdraw(uint wad) external;

  function transfer(address to, uint256 value) external returns (bool);
}
