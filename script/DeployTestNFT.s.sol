// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "@pixelaunch/PixelaunchNFT.sol";


contract DeployTestNFTScript is BaseScript {
    function deploy() public {
        PixelaunchNFT.FundsBeneficiary[] memory fundsBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](1);
        fundsBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({
            recipient: msg.sender,
            shares: 100
        });

        vm.startBroadcast();
        deploy("PixelaunchNFT", "PixelaunchNFT.sol:PixelaunchNFT", abi.encode(PixelaunchNFT.ConstructorParams({
            name: "Pixelaunch Test NFT",
            symbol: "PLT",
            maxSupply: 10000,
            maxWhitelistSupply: 1000,
            reservedSupply: 100,
            reservedSupplyRecipient: msg.sender,
            whitelistMintDuration: 60 minutes,
            mintFundsBeneficiaries: fundsBeneficiaries,
            royaltyFundsBeneficiaries: fundsBeneficiaries,
            mintStartTimestamp: block.timestamp + 2 days,
            whitelistMintPrice: 1 ether,
            publicMintPrice: 2 ether,
            maxWhitelistMintPerTx: 10,
            maxPublicMintPerTx: 10,
            maxWhitelistMintPerWallet: 100,
            maxPublicMintPerWallet: 100,
            royaltyBps: 500,
            baseURI: "https://api.pixelaunch.art/nft/"
        })));
        vm.stopBroadcast();
    }
}
