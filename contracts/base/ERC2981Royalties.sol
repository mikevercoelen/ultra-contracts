// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "../interfaces/IERC2981Royalties.sol";

abstract contract ERC2981Royalties is ERC165Storage, IERC2981Royalties {
  event RoyaltiesDefined(
    uint256 indexed id,
    address indexed recipient,
    uint256 value
  );

  bytes4 private constant _INTERFACE_ID_EIP2981 = 0xc155531d;
  uint private constant BP_DIVISOR = 10000;

  struct Royalty {
    address recipient;
    uint256 value;
  }

  mapping(uint256 => Royalty) internal _royalties;

  constructor() {
    _registerInterface(_INTERFACE_ID_EIP2981);
  }

  /**
   * @dev Set Royalties
   *
   * Requirements:
   *
   * - value should be lte 100%
   * - recipient can not be address(0)
   */
  function _setTokenRoyalty(
    uint256 id,
    address recipient,
    uint256 value
  ) internal {
    require(recipient != address(0), "Royalties: Invalid recipient");
    require(value <= BP_DIVISOR, "Royalties: Too high");

    _royalties[id] = Royalty(recipient, value);

    emit RoyaltiesDefined(id, recipient, value);
  }

  function royaltyInfo(
    uint256 tokenId,
    uint256 value,
    bytes calldata
  )
    external
    view
    override
    returns (
      address receiver,
      uint256 royaltyAmount,
      bytes memory royaltyPaymentData
    )
  {
    Royalty memory royalty = _royalties[tokenId];

    if (royalty.recipient == address(0)) {
      return (address(0), 0, "");
    }

    return (royalty.recipient, (value * royalty.value) / BP_DIVISOR, "");
  }
}
