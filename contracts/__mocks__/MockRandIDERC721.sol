// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
 
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import 'hardhat/console.sol';

contract MockRandIDERC721 is ERC721  {
 
    // uint16[] private ids;
    mapping(uint256=>uint16) public ids;
    uint256 private idsLength;
    uint16 private index;

    uint256[] private selIds;
 
    constructor() ERC721('RandomIdv1', 'RNDMv1') {
        // ids = new uint16[](50000);
        idsLength = 10;
    }
 
    function mint(address[] calldata _to) external {
        console.log("Length of _to", _to.length);
        for (uint256 i = 0; i < _to.length; i++) {
            uint256 seed = i + 1;
            uint256 _random = random(seed);
            // console.log('_random', _random);
            uint256 _pickRandomUniqueIdRes = _pickRandomUniqueId(_random);
            console.log('TokenID: _pickRandomUniqueIdRes:', _pickRandomUniqueIdRes);
            _safeMint(_to[i], _pickRandomUniqueIdRes);
        }
    }

    function random(uint256 seed) private view returns(uint256 _rand){
        _rand = uint256(keccak256(abi.encodePacked(seed, tx.origin, block.timestamp, blockhash(block.number-1))));
    }
 
    function _pickRandomUniqueId(uint256 _random) private returns (uint256 _id) {
        uint256 len = idsLength - index++;
        console.log('index', index);
        require(len > 0, 'no ids left');
        uint256 randomIndex = _random % len;

        console.log('randomIndex in 0 ~ 10', randomIndex);
        _id = (ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex) + 1;
        
        ids[randomIndex] = uint16(ids[len - 1] == 0 ? len - 1 : ids[len - 1]);
        ids[len - 1] = 0;
        
    }

    function addSelIds(uint256[] calldata _ids) public  returns (uint256 len){
        require(_ids.length > 0, "Invalid array");
        for (uint256 i = 0; i < _ids.length; i++) {
            selIds.push(_ids[i]);
        }
        return selIds.length;
    }

    function getItemAtSelIds(uint256 _index) public view returns(uint256) {
        require(_index >= 0 && _index < selIds.length, "Invalid index to get");
        
        return selIds[_index];
        
    }

    function removeItemAtSelIds(uint256 _index) public {
        require(_index >= 0 && _index < selIds.length, "Invalid index to remove");
        selIds[_index] = selIds[selIds.length - 1];
        selIds.pop();
    }

    function getLengthIds() public view returns(uint256) {
        return selIds.length;
    }

}