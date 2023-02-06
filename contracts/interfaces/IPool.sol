// SPDX-License-Identifier: MIT LICENSE 

pragma solidity 0.8.7;

interface IPool {
  function addManyToPool(address account, uint16[] calldata tokenIds, address _game) external;

  function getOwnerOfStakedToken( uint16 _tokenId, address _game) external view returns (address);

  function isStaked(address _game, uint16 _tokenId) external view returns(bool);

  
}