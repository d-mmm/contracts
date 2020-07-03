// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IMarketMakerLogic {
    function onTokenReceived(
        address token,
        address operator,
        address msgSender,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;

    function buyToken(
        address payable msgSender,
        uint256 msgValue,
        bytes calldata msgData
    ) external;

    function buyTokenFromERC20(
        address from,
        address token,
        uint256 amt
    ) external;
}
