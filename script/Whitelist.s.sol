// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "@pixelaunch/PixelaunchNFT.sol";


contract Whitelist is BaseScript {
    struct WhitelistSpot {
        address account;
        uint256 amount;
    }

    function addWhitelistSpots(PixelaunchNFT nft, string memory filename) external {
        string memory root = string.concat(vm.projectRoot(), "/");
        string memory path = string.concat(root, filename);
        bytes memory json = vm.parseJson(vm.readFile(path));
        WhitelistSpot[] memory spots = abi.decode(json, (WhitelistSpot[]));
        address[] memory addresses = abi.decode(json, (address[]));
        uint256[] memory amounts = new uint256[](addresses.length);

        for (uint256 i = 0; i < spots.length; i++) {
            addresses[i] = spots[i].account;
            amounts[i] = spots[i].amount;
        }

        vm.broadcast(msg.sender);
        nft.addWhitelistSpots(addresses, amounts);
    }
}
