// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC2981Royalties.sol";

contract UltrareumERC1155 is ERC1155Burnable, ERC2981Royalties {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  string private _baseURI;

  event CreateToken(
    uint256 timestamp,
    uint256 indexed tokenId,
    address indexed tokenMinter,
    uint256 indexed royaltyCut,
    uint256 tokenAmount,
    bytes tokenData
  );

  constructor(string memory uri_) ERC1155(uri_) {
    _baseURI = uri_;
  }

  function mint(
    uint256 _royaltyCut,
    uint256 _amount,
    bytes memory _data
  ) public returns (uint256) {
    _tokenIdCounter.increment();

    uint256 tokenId = _tokenIdCounter.current();
    _mint(msg.sender, tokenId, _amount, _data);

    if (_royaltyCut > 0) {
      _setTokenRoyalty(tokenId, msg.sender, _royaltyCut);
    }

    emit CreateToken(
      block.timestamp,
      tokenId,
      msg.sender,
      _royaltyCut,
      _amount,
      _data
    );

    return tokenId;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC1155, ERC165Storage)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
