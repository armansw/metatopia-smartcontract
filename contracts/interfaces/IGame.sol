// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.7;

import { DataTypes } from "../libraries/DataTypes.sol";


interface IGame {

  // struct to store each token's traits
  struct RunnerBull {

    address gameAddr;
    DataTypes.NFTType nftType;
    bool isValue;
  }
 
  function getTokenTraits(uint256 tokenId) external view returns (RunnerBull memory);

  function getMIN_STAKE_EXIT_DAYS() external view returns (uint80);

  // function getClaimDailyTopiaForTokenId(uint16 _tokenId) external view returns (uint256);

  function getUnstakeRiskRateForTokenId(uint16 _tokenId) external view returns (uint16);

  function getHarvestRiskRateForTokenId(uint16 _tokenId) external view returns (uint16);
  // function getHarvestRiskDistributeRateForTokenId(uint16 _tokenId) external view returns (uint16);

  function burn(uint256 tokenId) external;

  function getRandGameResult(uint256 seed, uint16 nftCount,uint16 nrOfWorker, uint16 nrOfStealer, uint16 nrOfManager ) external view returns (bool);

  
  function getPrizeAmountForOwner(uint16 _tokenId, uint256 _betAmount, bool _betForWorker, bool _workerWin) external view returns (uint256);
  function getPrizeAmountForBetPool(uint16 _tokenId, uint256 _betAmount, bool _betForWorker, bool _workerWin) external view returns (uint256);
  function getPrizeAmountToManagers(uint16 _tokenId, uint256 _betAmount, bool _workerWin) external view returns (uint256);


  function isWorker(uint256 tokenId) external view returns (bool worker);
  function isStealer(uint256 tokenId) external view returns (bool stealer);
  function isManager(uint256 tokenId) external view returns (bool manager);
  function isAlpha(uint256 tokenId) external view returns (bool manager);

  function getAvailableClaimAmount( uint16 _tokenId, uint80 _fromStamp, uint80 _toStamp) external view returns(uint256);


  function addStakedToken(uint16 _tokenId) external;
  function removeStakedToken(uint16 _tokenId) external;

  function getTotalStakedTokensFor(DataTypes.NFTType _nftType) external view returns (uint16 _total);
  function getStakedTokenAtIndex(uint16 _index, DataTypes.NFTType _nftType) external view returns (uint16 _tokenId);  
  function getTotalStakedTokens() external view returns (uint16 _total);

  
  function distributeHarvestRewards(uint256 _claimedAmountFrom, uint16 _fromTokenId) external;
  function getClaimAmountBesideHarvestTax(uint256 _claimAmount, uint16 _tokenId) external view returns (uint256 _netAmount);
  
  function getHarvestRewardsAmount (uint16 _tokenId) external view returns (uint256 _rewards);
  function cleanHarvestRewards(uint16 _tokenId) external;
  
}