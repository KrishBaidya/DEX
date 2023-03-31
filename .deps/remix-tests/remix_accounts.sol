// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

library TestsAccounts {
    function getAccount(uint index) pure public returns (address) {
        address[0] memory accounts;;
        return accounts[index];
    }
}
