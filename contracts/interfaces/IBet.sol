// SPDX-License-Identifier: MIT LICENSE 

pragma solidity 0.8.7;

interface IBet {


  struct BetRoom {
    
    uint16 nftCount;
    uint80 openedAt;
    bool opened;   
    uint16 nrOfWorker;
    uint16 nrOfStealer;
    uint16 nrOfManager;

    /** nftIndex to tokenId */
    mapping(uint16=>uint16) tokenIds;
    /** tokenId to betAmount */
    mapping(uint16=>uint256) betAmount;
    /** spectator tokenId to betforWorker */
    mapping(uint16=>bool) betForWorker;
  }

  function isOnBet(address _game, uint16 _tokenId) external view returns (bool);

}