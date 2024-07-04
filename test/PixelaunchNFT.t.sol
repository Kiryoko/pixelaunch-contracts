// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "@pixelaunch/PixelaunchNFT.sol";

contract PixelaunchNFTTest is BaseTest {
    PixelaunchNFT nft;
    PixelaunchNFT.ConstructorParams params;
    uint256 maxSupply = 10000;
    uint256 maxWhitelistSupply = 1000;
    uint256 reservedSupply = 100;
    address reservedSupplyRecipient;
    uint256 whitelistMintDuration = 60 minutes;
    uint256 mintStartTimestamp = block.timestamp + 2 days;
    uint256 whitelistMintPrice = 1 ether;
    uint256 publicMintPrice = 2 ether;
    uint256 maxWhitelistMintPerTx = 10;
    uint256 maxPublicMintPerTx = 10;
    uint256 maxWhitelistMintPerWallet = 100;
    uint256 maxPublicMintPerWallet = 100;
    uint96 royaltyBps = 500;

    function setUp() public override {
        super.setUp();

        reservedSupplyRecipient = carol;

        PixelaunchNFT.FundsBeneficiary[] memory fundsBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](1);
        fundsBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({recipient: carol, shares: 100});

        nft = new PixelaunchNFT(
            PixelaunchNFT.ConstructorParams({
                name: "Pixelaunch Test NFT",
                symbol: "PLT",
                maxSupply: maxSupply,
                maxWhitelistSupply: maxWhitelistSupply,
                reservedSupply: reservedSupply,
                reservedSupplyRecipient: reservedSupplyRecipient,
                whitelistMintDuration: whitelistMintDuration,
                mintFundsBeneficiaries: fundsBeneficiaries,
                royaltyFundsBeneficiaries: fundsBeneficiaries,
                mintStartTimestamp: mintStartTimestamp,
                whitelistMintPrice: whitelistMintPrice,
                publicMintPrice: publicMintPrice,
                maxWhitelistMintPerTx: maxWhitelistMintPerTx,
                maxPublicMintPerTx: maxPublicMintPerTx,
                maxWhitelistMintPerWallet: maxWhitelistMintPerWallet,
                maxPublicMintPerWallet: maxPublicMintPerWallet,
                royaltyBps: royaltyBps,
                baseURI: "https://api.pixelaunch.art/nft/"
            })
        );

        assertEq(nft.name(), "Pixelaunch Test NFT");
        assertEq(nft.symbol(), "PLT");
        assertEq(nft.MAX_SUPPLY(), maxSupply);
        assertEq(nft.MAX_WHITELIST_SUPPLY(), maxWhitelistSupply);
        assertEq(nft.RESERVED_SUPPLY(), reservedSupply);
        assertEq(nft.RESERVED_SUPPLY_RECIPIENT(), reservedSupplyRecipient);
        assertEq(nft.whitelistMintDuration(), whitelistMintDuration);
        assertEq(nft.mintStartTimestamp(), mintStartTimestamp);
        assertEq(nft.publicMintPrice(), publicMintPrice);
        assertEq(nft.whitelistMintPrice(), whitelistMintPrice);
        assertEq(nft.maxWhitelistMintPerTx(), maxWhitelistMintPerTx);
        assertEq(nft.maxPublicMintPerTx(), maxPublicMintPerTx);
        assertEq(nft.maxWhitelistMintPerWallet(), maxWhitelistMintPerWallet);
        assertEq(nft.maxPublicMintPerWallet(), maxPublicMintPerWallet);
        assertEq(nft.baseURI(), "https://api.pixelaunch.art/nft/");

        assertEq(nft.totalSupply(), reservedSupply);
        assertEq(nft.ownerOf(0), carol);
        assertEq(nft.ownerOf(reservedSupply - 1), carol);

        vm.warp(mintStartTimestamp + whitelistMintDuration);
    }

    function testPublicMint() public {
        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(reservedSupply), alice);
        assertEq(nft.totalSupply(), reservedSupply + 1);
        assertEq(carol.balance, defaultInitialUserBalance + publicMintPrice);
    }

    function testPublicMintWithoutPayment() public {
        vm.expectRevert(PixelaunchNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.publicMint{value: 0}(1);
        vm.stopPrank();
    }

    function testPublicMintWithExcessPayment() public {
        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice + 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(reservedSupply), alice);
        assertEq(nft.totalSupply(), reservedSupply + 1);
        assertEq(carol.balance, defaultInitialUserBalance + publicMintPrice);
        assertEq(alice.balance, defaultInitialUserBalance - publicMintPrice);
    }

    function testPublicMintWithInsufficientPayment() public {
        vm.expectRevert(PixelaunchNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice - 1}(1);
        vm.stopPrank();
    }

    function testPublicMintWithZeroAmount() public {
        vm.expectRevert(PixelaunchNFT.InvalidAmount.selector);
        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice}(0);
        vm.stopPrank();
    }

    function testPublicMintingNotStarted() public {
        vm.warp(mintStartTimestamp);

        vm.expectRevert(PixelaunchNFT.MintingNotStarted.selector);
        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
    }

    function testWhitelistMint() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.startPrank(alice);
        nft.whitelistMint{value: whitelistMintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(reservedSupply), alice);
        assertEq(nft.totalSupply(), reservedSupply + 1);
        assertEq(carol.balance, defaultInitialUserBalance + whitelistMintPrice);
    }

    function testWhitelistMintWithoutPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.expectRevert(PixelaunchNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.whitelistMint{value: 0}(1);
        vm.stopPrank();
    }

    function testWhitelistMintWithExcessPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.startPrank(alice);
        nft.whitelistMint{value: whitelistMintPrice + 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(reservedSupply), alice);
        assertEq(nft.totalSupply(), reservedSupply + 1);
        assertEq(carol.balance, defaultInitialUserBalance + whitelistMintPrice);
        assertEq(alice.balance, defaultInitialUserBalance - whitelistMintPrice);
    }

    function testWhitelistMintWithInsufficientPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.expectRevert(PixelaunchNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.whitelistMint{value: whitelistMintPrice - 1}(1);
        vm.stopPrank();
    }

    function testWhitelistMintWithZeroAmount() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.expectRevert(PixelaunchNFT.InvalidAmount.selector);
        vm.startPrank(alice);
        nft.whitelistMint{value: whitelistMintPrice}(0);
        vm.stopPrank();
    }

    function testWhitelistMintingNotStarted() public {
        vm.warp(mintStartTimestamp - 1);
        nft.addWhitelistSpots(alice, 1);

        vm.expectRevert(PixelaunchNFT.MintingNotStarted.selector);
        vm.startPrank(alice);
        nft.whitelistMint{value: whitelistMintPrice}(1);
        vm.stopPrank();
    }

    function testTokensOfOwner() public {
        assertEq(nft.tokensOfOwner(carol).length, reservedSupply);
        assertEq(nft.tokensOfOwner(carol)[0], 0);
        assertEq(nft.tokensOfOwner(carol)[reservedSupply - 1], reservedSupply - 1);

        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], reservedSupply);

        vm.startPrank(alice);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
        assertEq(nft.tokensOfOwner(alice).length, 2);
        assertEq(nft.tokensOfOwner(alice)[0], reservedSupply);
        assertEq(nft.tokensOfOwner(alice)[1], reservedSupply + 1);

        vm.prank(alice);
        nft.transferFrom(alice, bob, reservedSupply);
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], reservedSupply + 1);
        assertEq(nft.tokensOfOwner(bob).length, 1);
        assertEq(nft.tokensOfOwner(bob)[0], reservedSupply);
    }

    function testRoyaltyInfo() public view {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 10_000);
        assertEq(receiver, address(nft.royaltyFundsBeneficiary()));
        assertEq(royaltyAmount, royaltyBps);
    }

    function testSetPublicMintPrice() public {
        nft.setPublicMintPrice(100);
        assertEq(nft.publicMintPrice(), 100);
    }

    function testSetPublicMintPriceUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setPublicMintPrice(100);
    }

    function testSetWhitelistMintPrice() public {
        nft.setWhitelistMintPrice(100);
        assertEq(nft.whitelistMintPrice(), 100);
    }

    function testSetWhitelistMintPriceUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setWhitelistMintPrice(100);
    }

    function testSetMintStartTimestamp() public {
        vm.warp(mintStartTimestamp - 1);
        nft.setMintStartTimestamp(block.timestamp + 1);
        assertEq(nft.mintStartTimestamp(), block.timestamp + 1);
    }

    function testSetMintStartTimestampUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMintStartTimestamp(block.timestamp + 1);
    }

    function testSetDefaultRoyalty() public {
        nft.setDefaultRoyalty(address(this), 1000);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, address(this));
        assertEq(royaltyAmount, 10);
    }

    function testSetDefaultRoyaltyUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setDefaultRoyalty(address(this), 1000);
    }

    function testSetBaseURI() public {
        nft.setBaseURI("https://example.com/");
        assertEq(nft.baseURI(), "https://example.com/");
        assertEq(nft.tokenURI(1), "https://example.com/1");
    }

    function testSetBaseURIUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setBaseURI("https://example.com/");
    }

    function testPauseUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.pause();
    }

    function testUnpauseUnauthorized() public {
        nft.pause();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.unpause();
    }

    function testWithdrawUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.withdraw();
    }

    function testSetWhitelistMintDurationUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setWhitelistMintDuration(2 hours);
    }

    function testSetMaxWhitelistMintPerTxUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMaxWhitelistMintPerTx(5);
    }

    function testSetMaxPublicMintPerTxUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMaxPublicMintPerTx(5);
    }

    function testSetMaxWhitelistMintPerWalletUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMaxWhitelistMintPerWallet(50);
    }

    function testSetMaxPublicMintPerWalletUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMaxPublicMintPerWallet(50);
    }

    function testSetRoyaltyFundsBeneficiariesUnauthorized() public {
        PixelaunchNFT.FundsBeneficiary[] memory newBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](1);
        newBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({recipient: alice, shares: 100});

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setRoyaltyFundsBeneficiaries(newBeneficiaries);
    }

    function testSetMintFundsBeneficiariesUnauthorized() public {
        PixelaunchNFT.FundsBeneficiary[] memory newBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](1);
        newBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({recipient: alice, shares: 100});

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMintFundsBeneficiaries(newBeneficiaries);
    }

    function testSetMintStartTimestampAfterMintStarted() public {
        vm.warp(mintStartTimestamp + 1);

        vm.expectRevert(PixelaunchNFT.MintingAlreadyStarted.selector);
        nft.setMintStartTimestamp(block.timestamp + 1 days);
    }

    function testSetWhitelistMintDurationAfterMintStarted() public {
        vm.warp(mintStartTimestamp + 1);

        vm.expectRevert(PixelaunchNFT.MintingAlreadyStarted.selector);
        nft.setWhitelistMintDuration(2 hours);
    }

    function testSetDefaultRoyaltyTooHigh() public {
        vm.expectRevert(PixelaunchNFT.RoyaltyTooHigh.selector);
        nft.setDefaultRoyalty(address(this), 1501); // 15.01% is too high
    }

    function testSetMintStartTimestampInPast() public {
        vm.warp(mintStartTimestamp - 1 days);

        vm.expectRevert(PixelaunchNFT.TimestampInThePast.selector);
        nft.setMintStartTimestamp(block.timestamp - 1);
    }

    function testAddWhitelistSpots() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 0);

        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testRemoveWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 2);

        vm.expectRevert(Whitelistable.NotEnoughWhitelistSpots.selector);
        nft.removeWhitelistSpots(alice, 3);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testClearWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 0);
    }

    function testMultipleAddWhitelistSpots() public {
        address[] memory addresses = new address[](3);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(PixelaunchNFT.ArrayLengthMismatch.selector);
        nft.addWhitelistSpots(addresses, amounts);

        amounts = new uint256[](3);

        addresses[0] = alice;
        addresses[1] = alice;
        addresses[2] = address(1337);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 2;
        nft.addWhitelistSpots(addresses, amounts);
        assertEq(nft.whitelistSpots(alice), 2);
        assertEq(nft.whitelistSpots(address(1337)), 2);
    }

    function testMaxSupplyReached() public {
        uint256 remainingSupply = maxSupply - reservedSupply;
        vm.deal(alice, publicMintPrice * (remainingSupply + 1));
        nft.setMaxPublicMintPerWallet(maxSupply);

        vm.pauseGasMetering();

        bytes32 free_mem;
        assembly ("memory-safe") {
            free_mem := mload(0x40)
        }

        vm.startPrank(alice);
        for (uint256 i = 0; i < remainingSupply; i++) {
            nft.publicMint{value: publicMintPrice}(1);
            assembly ("memory-safe") {
                mstore(0x40, free_mem)
            }
        }

        vm.expectRevert(PixelaunchNFT.MaxSupplyReached.selector);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
    }

    function testMaxWhitelistSupplyReached() public {
        vm.warp(nft.mintStartTimestamp());

        nft.setMaxWhitelistMintPerWallet(maxSupply);

        uint256 remainingWhitelistSupply = nft.MAX_WHITELIST_SUPPLY();
        vm.deal(alice, publicMintPrice * remainingWhitelistSupply);
        nft.addWhitelistSpots(alice, remainingWhitelistSupply + 1);

        vm.startPrank(alice);
        for (uint256 i = 0; i < remainingWhitelistSupply; i++) {
            nft.whitelistMint{value: whitelistMintPrice}(1);
        }

        vm.expectRevert(PixelaunchNFT.MaxWhitelistSupplyReached.selector);
        nft.whitelistMint{value: whitelistMintPrice}(1);
        vm.stopPrank();
    }

    function testWhitelistMintingEnded() public {
        vm.warp(nft.mintStartTimestamp() + nft.whitelistMintDuration() + 1);

        nft.addWhitelistSpots(alice, 1);

        vm.expectRevert(PixelaunchNFT.WhitelistMintingEnded.selector);
        vm.prank(alice);
        nft.whitelistMint{value: whitelistMintPrice}(1);
    }

    function testMaxWhitelistMintPerTxExceeded() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, maxWhitelistMintPerTx + 1);

        vm.expectRevert(PixelaunchNFT.MaxWhitelistMintPerTxExceeded.selector);
        vm.prank(alice);
        nft.whitelistMint{value: whitelistMintPrice * (maxWhitelistMintPerTx + 1)}(maxWhitelistMintPerTx + 1);
    }

    function testMaxPublicMintPerTxExceeded() public {
        vm.expectRevert(PixelaunchNFT.MaxPublicMintPerTxExceeded.selector);
        vm.prank(alice);
        nft.publicMint{value: publicMintPrice * (maxPublicMintPerTx + 1)}(maxPublicMintPerTx + 1);
    }

    function testMaxWhitelistMintPerWalletExceeded() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, nft.maxWhitelistMintPerWallet() + 1);

        vm.deal(alice, publicMintPrice * (maxPublicMintPerWallet + 1));
        vm.startPrank(alice);
        for (uint256 i = 0; i < nft.maxWhitelistMintPerWallet(); i++) {
            nft.whitelistMint{value: whitelistMintPrice}(1);
        }

        vm.expectRevert(PixelaunchNFT.MaxWhitelistMintPerWalletExceeded.selector);
        nft.whitelistMint{value: whitelistMintPrice}(1);
        vm.stopPrank();
    }

    function testMaxPublicMintPerWalletExceeded() public {
        vm.deal(alice, publicMintPrice * (maxPublicMintPerWallet + 1));
        vm.startPrank(alice);
        for (uint256 i = 0; i < nft.maxPublicMintPerWallet(); i++) {
            nft.publicMint{value: publicMintPrice}(1);
        }

        vm.expectRevert(PixelaunchNFT.MaxPublicMintPerWalletExceeded.selector);
        nft.publicMint{value: publicMintPrice}(1);
        vm.stopPrank();
    }

    function testSetWhitelistMintDuration() public {
        vm.warp(mintStartTimestamp - 1);
        nft.setWhitelistMintDuration(2 hours);
        assertEq(nft.whitelistMintDuration(), 2 hours);
    }

    function testSetMaxWhitelistMintPerTx() public {
        nft.setMaxWhitelistMintPerTx(5);
        assertEq(nft.maxWhitelistMintPerTx(), 5);
    }

    function testSetMaxPublicMintPerTx() public {
        nft.setMaxPublicMintPerTx(5);
        assertEq(nft.maxPublicMintPerTx(), 5);
    }

    function testSetMaxWhitelistMintPerWallet() public {
        nft.setMaxWhitelistMintPerWallet(50);
        assertEq(nft.maxWhitelistMintPerWallet(), 50);
    }

    function testSetMaxPublicMintPerWallet() public {
        nft.setMaxPublicMintPerWallet(50);
        assertEq(nft.maxPublicMintPerWallet(), 50);
    }

    function testSetRoyaltyFundsBeneficiaries() public {
        PixelaunchNFT.FundsBeneficiary[] memory newBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](2);
        newBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({recipient: alice, shares: 60});
        newBeneficiaries[1] = PixelaunchNFT.FundsBeneficiary({recipient: bob, shares: 40});

        nft.setRoyaltyFundsBeneficiaries(newBeneficiaries);

        (address receiver, ) = nft.royaltyInfo(0, 100);
        assertEq(receiver, nft.royaltyFundsBeneficiary());
    }

    function testSetMintFundsBeneficiaries() public {
        PixelaunchNFT.FundsBeneficiary[] memory newBeneficiaries = new PixelaunchNFT.FundsBeneficiary[](2);
        newBeneficiaries[0] = PixelaunchNFT.FundsBeneficiary({recipient: alice, shares: 60});
        newBeneficiaries[1] = PixelaunchNFT.FundsBeneficiary({recipient: bob, shares: 40});

        nft.setMintFundsBeneficiaries(newBeneficiaries);

        assertEq(nft.mintFundsBeneficiary(), address(nft.mintFundsBeneficiary()));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
