// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./MooNFT.sol";

contract PackNFT is
  ERC721Enumerable,
  Ownable
{

  MooNFT immutable mooNft;
  uint public numMinted = 0;
  uint public maxPacks = 8000;
  // uint public price = 1 ether;
  uint public maxPurchaseQty = 10;

  constructor(string memory _name, string memory _symbol, address _mooNft)
    ERC721(_name, _symbol)
  {
    mooNft = MooNFT(_mooNft);
  }

  function buy(uint _qty) external payable {
    require(_qty > 0, "Purchase quantity must be at least 1");
    require(_qty <= maxPurchaseQty, "Purchase quantity exceeds maximum");
    require((numMinted + _qty) <= maxPacks, "Purchase quantity exceeds total packs");

    for (uint i = 0; i < _qty; i++) {
      _mint(msg.sender, ++numMinted);
    }
  }

  function open(uint _tokenId) external {
    require(ERC721.ownerOf(_tokenId) == msg.sender, "Must be owner");
    super._burn(_tokenId);
    mooNft.mint(msg.sender, 10);
  }

  function mooNftAddress() external view returns (address) {
    return address(mooNft);
  }

  function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
    uint256[] memory tokens = new uint256[](balanceOf(_owner));
    for (uint256 i = 0; i < balanceOf(_owner); i++) {
      tokens[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokens;
  }

}
