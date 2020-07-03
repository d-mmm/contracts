// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IDeFiLogic {
    function onTokenReceived(
        address token,
        address operator,
        address msgSender,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;

    function getOriginalAccountQuota()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function register(
        address msgSender,
        uint256 msgValue,
        bytes32 inviteCode,
        bool purchaseOriginAccount
    ) external;

    function claimROI(address msgSender) external;

    function deposit(
        address msgSender,
        uint256 poolID,
        uint256 tokenAmt
    ) external;
}
