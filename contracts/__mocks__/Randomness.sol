// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import 'hardhat/console.sol';

contract Randomness is Ownable {

    mapping(address=>bool) isCaller;

    constructor(){}
    
    function getRandom(uint256 seed) external view returns (uint256) {
        require(isCaller[msg.sender], "invalid caller");
        uint256 _seedRand = random(seed);        
        return random(_seedRand);
    }
    
    function random(uint256 seed) private view returns(uint256 _rand){
        // _rand = uint256(keccak256(abi.encodePacked(seed, tx.origin, block.timestamp, blockhash(block.number-1))));
        _rand = uint256(keccak256(abi.encodePacked(seed, tx.origin, blockhash(block.number-1), block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) + block.number)));

    }

    function addCaller(address _caller) external onlyOwner {
        isCaller[_caller] = true;
    }
    function removeCaller(address _caller) external onlyOwner {
        isCaller[_caller] = false;
    }

}