// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "@pixelaunch/extensions/Whitelistable.sol";

contract WhitelistableTest is BaseTest, Whitelistable {
    function testAddWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 1);
        assertEq(whitelistSpots[msg.sender], 1);
    }

    function testRemoveWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 1);
        vm.expectRevert(NotEnoughWhitelistSpots.selector);
        _removeWhitelistSpots(msg.sender, 5);
        _removeWhitelistSpots(msg.sender, 1);
        assertEq(whitelistSpots[msg.sender], 0);
    }

    function testClearWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 123);
        _clearWhitelistSpots(msg.sender);
        assertEq(whitelistSpots[msg.sender], 0);
    }

    function _whitelistOnlyFunction() private onlyWhitelisted {}

    function testWhitelistOnlyModifier() public {
        vm.expectRevert(NotEnoughWhitelistSpots.selector);
        _whitelistOnlyFunction();
        _addWhitelistSpots(address(this), 42);
        _whitelistOnlyFunction();
    }
}
