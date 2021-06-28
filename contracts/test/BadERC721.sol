// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract BadERC721 is ERC165 {
  function supportsInterface(bytes4 _interface)
    public
    view
    override
    returns (bool)
  {
    return false;
  }
}
