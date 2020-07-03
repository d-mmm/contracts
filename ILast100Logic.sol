// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface ILast100Logic {
    function checkUserAvailable(address payable from)
        external
        returns (uint256);

    function internalExchange() external;
}
