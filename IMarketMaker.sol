// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IMarketMaker {
    function sendToken(
        address token,
        address to,
        uint256 amt
    ) external;

    function sendETH(address payable to, uint256 amt) external;
}
