// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.26;

import "@pixelaunch/PaymentSplitter.sol";

contract RoyaltyPaymentSplitter is PaymentSplitter {
    uint256 _payeesCount;

    constructor(address[] memory payees_, uint256[] memory shares_) PaymentSplitter(payees_, shares_) {
        _payeesCount = payees_.length;
    }

    function releaseAll() external {
        for (uint256 i = 0; i < _payeesCount; i++) {
            address payee = super.payee(i);
            super.release(payable(payee));
        }
    }
}
