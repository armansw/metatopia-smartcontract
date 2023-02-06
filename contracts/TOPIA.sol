// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TOPIA is ERC20, Ownable, Pausable {

  // a mapping from an address to whether or not it can mint / burn
  mapping(address => bool) controllers;
  
  constructor() ERC20("TOPIA", "TOPIA") { }

  /**
   * mints $TOPIA to a recipient
   * @param to the recipient of the $TOPIA
   * @param amount the amount of $TOPIA to mint
   */
  function mint(address to, uint256 amount) external whenNotPaused{
    require(controllers[msg.sender], "Only controllers can mint");
    _mint(to, amount);
  }

  /**
   * burns $TOPIA from a holder
   * @param from the holder of the $TOPIA
   * @param amount the amount of $TOPIA to burn
   */
  function burn(address from, uint256 amount) external whenNotPaused {
    require(controllers[msg.sender], "Only controllers can burn");
    _burn(from, amount);
  }

  /**
   * enables an address to mint / burn
   * @param controller the address to enable
   */
  function addController(address controller) external onlyOwner {
    controllers[controller] = true;
  }

  /**
   * disables an address from minting / burning
   * @param controller the address to disbale
   */
  function removeController(address controller) external onlyOwner {
    controllers[controller] = false;
  }
}