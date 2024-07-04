// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "@pixelaunch/RoyaltyPaymentSplitter.sol";

contract RoyaltyPaymentSplitterTest is BaseTest {
    RoyaltyPaymentSplitter paymentSplitter;

    function setUp() public override {
        defaultInitialUserBalance = 0;
        super.setUp();

        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);

        payees[0] = alice;
        payees[1] = bob;
        shares[0] = 1;
        shares[1] = 2;

        paymentSplitter = new RoyaltyPaymentSplitter(payees, shares);

    }

    function testReleaseAll() public {
        vm.deal(address(paymentSplitter), 3 ether);
        paymentSplitter.releaseAll();
        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 2 ether);

        vm.deal(address(this), 3 ether);
        (bool success, ) = address(paymentSplitter).call{value: 3 ether}("");
        assertTrue(success);
        paymentSplitter.releaseAll();
        assertEq(alice.balance, 2 ether);
        assertEq(bob.balance, 4 ether);
    }
}
