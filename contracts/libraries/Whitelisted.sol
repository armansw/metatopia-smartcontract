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
abstract contract Whitelisted is Context, Ownable {
    
    mapping(address => bool) private isWhiteListed;

    /**
     * @dev owner ( deployer ) is whitelisted normally.
     */
    constructor() {
        isWhiteListed[_msgSender()] = true;
    }

    /**
     * @dev Returns boolean if _user is whitelisted then true else false.
     */
    function getWhitelisted(address _user) public view virtual returns (bool) {
        return isWhiteListed[_user];
    }

    /**
     * @dev Throws if called by any account other than whitelisted.
     */
    modifier onlyWhitelisted() {
        require( isWhiteListed[_msgSender()], "Whitelisted: caller is not whitelisted.");
        _;
    }

    /**
     * @dev only owner can update whitelist.
     */
    function addWhitelisted(address _user) public virtual onlyOwner {
        require(isWhiteListed[_user] == false, "Already whitelisted.");
        isWhiteListed[_user] = true;
    }
    /**
     * @dev only owner can remove whitelisted user.
     */
    function removeWhitelisted(address _user) public virtual onlyOwner {
        require(isWhiteListed[_user] == true, "Not whitelisted.");
        isWhiteListed[_user] = false;
    }

}
