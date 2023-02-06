//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    uint256 internal counter = 0;

   function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32 count
    ) external returns (uint256 requestId) {
        VRFConsumerBaseV2 consumer = VRFConsumerBaseV2(msg.sender);
        uint256[] memory randomWords = new uint256[](count);

        for (uint32 i = 0 ; i < count; i ++){
            randomWords[i] = random(counter);
            counter += 1;
        }
        requestId = counter;
        consumer.rawFulfillRandomWords(requestId, randomWords);
        
    }
}
