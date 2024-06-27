// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "@pixelaunch/RoyaltyPaymentSplitter.sol";

contract RoyaltyPaymentSplitterTest is BaseTest {
    function setUp() public override {
        fork(ChainId.Taiko, 102971);
        super.setUp();
    }

    function testReleaseAll() public {
        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);

        payees[0] = address(1);
        payees[1] = address(2);
        shares[0] = 1;
        shares[1] = 2;

        RoyaltyPaymentSplitter paymentSplitter = new RoyaltyPaymentSplitter(payees, shares);

        vm.deal(address(paymentSplitter), 1 ether);
        paymentSplitter.releaseAll();
        assertEq(address(1).balance, uint256(1 ether * 1) / 3);
        assertEq(address(2).balance, uint256(1 ether * 2) / 3);

        vm.deal(address(this), 3 ether);
        (bool success, ) = address(paymentSplitter).call{value: 3 ether}("");
        assertTrue(success);
        paymentSplitter.releaseAll();
        assertEq(address(1).balance, uint256(4 ether * 1) / 3);
        assertEq(address(2).balance, uint256(4 ether * 2) / 3);
    }
}
