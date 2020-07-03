// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IGlobalLogic {
    function checkUserAlive(
        uint256 userID,
        uint256 roundID,
        uint256 lastActiveBlock,
        address userAddr
    ) external returns (bool);

    function checkDeactiveReferrals(uint256 userID) external;

    function generateInviteCode(uint256 id) external view returns (bytes32);

    function internalSplitPool() external;
}
