// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";

contract MooNFT is
  ERC721Enumerable,
  VRFConsumerBaseV2,
  Ownable
{
  mapping (address => bool) public minters;
  uint24[] public mintable;
  uint24 public numMintPending = 0;
  uint24 constant maxTokens = 80000;
  uint24 public totalTokens = 0;
  string public baseTokenURI;

  mapping (uint => address) public requestIdToOwner;
  mapping (uint => uint24) public requestIdToCount;
  mapping (uint => uint) public requestIdToBlockNum;

  VRFCoordinatorV2Interface clCoordinator;
  address constant clVrfCoordinator = 0xbd13f08b8352A3635218ab9418E340c60d6Eb418;
  bytes32 public clKeyHash = 0x121a143066e0f2f08b620784af77cccb35c6242460b4a8ee251b4b416abaebd4;
  uint32 public clCallbackGasLimit = 2000000;
  uint16 public clRequestConfirmations = 1;
  uint64 public clSubscriptionId = 86;

  constructor(string memory _name, string memory _symbol)
    ERC721(_name, _symbol)
    VRFConsumerBaseV2(clVrfCoordinator)
  {
    clCoordinator = VRFCoordinatorV2Interface(clVrfCoordinator);
  }

  function configChainlink(
    bytes32 _keyHash,
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint64 _subscriptionId
    ) external onlyOwner {
    clKeyHash = _keyHash;
    clCallbackGasLimit = _callbackGasLimit;
    clRequestConfirmations = _requestConfirmations;
    clSubscriptionId = _subscriptionId;
  }

  function setMinter(address _minter, bool _allow) external onlyOwner {
    minters[_minter] = _allow;
  }

  function initMintable(uint _count) external onlyOwner {
    uint24 _totalTokens = totalTokens;
    require((_totalTokens + _count) < maxTokens, "Exceeds max tokens");

    for (uint i = 0; i < _count; i++) {
      mintable.push(uint24(++_totalTokens));
    }
    totalTokens = _totalTokens;
  }

  function numMintable() public view returns (uint) {
    return mintable.length - numMintPending;
  }

  function numMinted() external view returns (uint) {
    return totalTokens - mintable.length;
  }

  function mint(address _to, uint24 _count)
    public
  {
    require(minters[msg.sender], "Invalid minter");
    require(_count <= numMintable(), "Insufficent mintable tokens");

    // initiate vrf request
    uint requestId = clCoordinator.requestRandomWords(
      clKeyHash,
      clSubscriptionId,
      clRequestConfirmations,
      clCallbackGasLimit,
      _count
    );

    // store request details
    numMintPending += _count;
    requestIdToOwner[requestId] = _to;
    requestIdToCount[requestId] = _count;
    requestIdToBlockNum[requestId] = block.number;
  }

  function retryMint(uint _requestId) external {
    require(requestIdToBlockNum[_requestId] != 0, "Invalid request");
    require((block.number - requestIdToBlockNum[_requestId]) > 100000, "Too soon");

    // initiate vrf request
    uint newRequestId = clCoordinator.requestRandomWords(
      clKeyHash,
      clSubscriptionId,
      clRequestConfirmations,
      clCallbackGasLimit,
      requestIdToCount[_requestId]
    );

    // store new request details
    requestIdToOwner[newRequestId] = requestIdToOwner[_requestId];
    requestIdToCount[newRequestId] = requestIdToCount[_requestId];
    requestIdToBlockNum[newRequestId] = block.number;

    // clear old request details
    delete requestIdToOwner[_requestId];
    delete requestIdToCount[_requestId];
    delete requestIdToBlockNum[_requestId];
  }

  function fulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
    ) internal override
  {
    require(requestIdToCount[requestId] == randomWords.length, "Corrupt request");
    address to = requestIdToOwner[requestId];

    for (uint256 i = 0; i < randomWords.length; i++) {
      uint256 index = randomWords[i] % mintable.length;
      uint256 tokenId = mintable[index];
      mintable[index] = mintable[mintable.length - 1];
      mintable.pop();
      _mint(to, tokenId);
    }

    // clear request details
    numMintPending -= requestIdToCount[requestId];
    delete requestIdToOwner[requestId];
    delete requestIdToCount[requestId];
    delete requestIdToBlockNum[requestId];
  }

  function powerLevel(uint _tokenId) external pure returns (uint) {
    return uint(keccak256(abi.encode(_tokenId))) % 100 + 1;
  }

  function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
    uint256[] memory tokens = new uint256[](balanceOf(_owner));
    for (uint256 i = 0; i < balanceOf(_owner); i++) {
      tokens[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokens;
  }

  function _baseURI() internal override(ERC721) view returns (string memory) {
      return baseTokenURI;
  }

  function setBaseTokenURI(string calldata _baseTokenURI) external onlyOwner {
    baseTokenURI = _baseTokenURI;
  }

}
