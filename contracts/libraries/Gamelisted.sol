// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Gamelisted is Context, Ownable {
    
    mapping(address => bool) private isListedGame;

    /**
     * @dev owner ( deployer ) is whitelisted normally.
     */
    constructor() {}

    /**
     * @dev Returns boolean if _user is whitelisted then true else false.
     */
    function getGamelisted(address _game) public view virtual returns (bool) {
        return isListedGame[_game];
    }

    /**
     * @dev Throws if called by any account other than whitelisted.
     */
    modifier onlyGamelisted(address _game) {
        require( isListedGame[_game], "GameListed: game is not listed.");
        _;
    }

    /**
     * @dev only owner can update whitelist.
     */
    function addGamelisted(address _game) public virtual onlyOwner {
        require(isListedGame[_game] == false, "Already listed game.");
        isListedGame[_game] = true;
    }
    /**
     * @dev only owner can remove whitelisted user.
     */
    function removeGamelisted(address _game) public virtual onlyOwner {
        require(isListedGame[_game] == true, "Not game listed.");
        isListedGame[_game] = false;
    }

}
