// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IDeFi {
    function sendToken(address to, uint256 amt) external;

    function sendETH(address payable to, uint256 amt) external;
}
