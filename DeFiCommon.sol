// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./Common.sol";


contract DeFiCommon is Common {
    event Error(string reason, uint256 extData, uint256 blockNumber);
}
