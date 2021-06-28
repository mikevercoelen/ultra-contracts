// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC2981Royalties.sol";

contract UltrareumERC721 is ERC2981Royalties, ERC721URIStorage, ERC721Burnable {
  using Counters for Counters.Counter;

  string private baseTokenURI;

  Counters.Counter private _tokenIdCounter;

  event CreateToken(
    uint256 timestamp,
    uint256 indexed tokenId,
    address indexed tokenMinter,
    uint256 indexed royaltyCut,
    string metadataId
  );

  constructor(string memory _baseTokenURI) ERC721("UltrareumERC721", "TC721") {
    baseTokenURI = _baseTokenURI;
  }

  function mint(uint256 royaltyCut, string calldata metadataId)
    public
    returns (uint256)
  {
    uint256 tokenId = _tokenIdCounter.current();
    _mint(msg.sender, tokenId);

    if (royaltyCut > 0) {
      _setTokenRoyalty(tokenId, msg.sender, royaltyCut);
    }

    _tokenIdCounter.increment();

    emit CreateToken(
      block.timestamp,
      tokenId,
      msg.sender,
      royaltyCut,
      metadataId
    );

    return tokenId;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC165Storage)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
