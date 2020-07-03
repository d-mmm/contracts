// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IDeFiStorage {
    enum ConfigType {
        InvestAmt,
        StaticIncomeAmt,
        DynamicIncomePercent,
        ClaimFeePercent,
        UpgradeRequiredInviteValidPlayerCount,
        UpgradeRequiredMarketPerformance,
        UpgradeRequiredSelfInvestCount
    }
    enum InvestType {Newbie, Open, PreOrder}
    enum GlobalStatus {Pending, Started, Bankruptcy, Ended}
    event GlobalBlocks(uint256 indexed eventID, uint256[3] blocks);

    // public
    function getCurrentRoundID(bool enableCurrentBlock)
        external
        view
        returns (uint256);

    function getAvailableRoundID(bool isNewUser, bool enableCurrentBlock)
        external
        view
        returns (uint256 id, InvestType investType);

    function getInvestGear(uint256 usdAmt) external view returns (uint256);

    function U2T(uint256 usdAmt) external view returns (uint256);

    function U2E(uint256 usdAmt) external view returns (uint256);

    function T2U(uint256 tokenAmt) external view returns (uint256);

    function E2U(uint256 etherAmt) external view returns (uint256);

    function T2E(uint256 tokenAmt) external view returns (uint256);

    function E2T(uint256 etherAmt) external view returns (uint256);

    function getGlobalStatus() external view returns (GlobalStatus);

    function last100() external view returns (uint256[100] memory);

    function getGlobalBlocks() external view returns (uint256[3] memory);

    function getDeFiAccounts() external view returns (uint256[5] memory);

    function getPoolSplitStats() external view returns (uint256[3] memory);

    function getPoolSplitPercent(uint256 roundID) external view returns (uint256[6] memory splitPrcent, uint256[2] memory nodeCount);

    // internal
    function isLast100AndLabel(uint256 userID) external returns (bool);

    function increaseRoundData(
        uint256 roundID,
        uint256 dataID,
        uint256 num
    ) external;

    function getNodePerformance(
        uint256 roundID,
        uint256 nodeID,
        bool isSuperNode
    ) external view returns (uint256);

    function increaseUserData(
        uint256 userID,
        uint256 dataID,
        uint256 num,
        bool isSub,
        bool isSet
    ) external;

    function checkRoundAvailableAndUpdate(
        bool isNewUser,
        uint256 roundID,
        uint256 usdAmt,
        uint256 tokenAmt
    ) external returns (bool success);

    function increaseDeFiAccount(
        uint256 accountID,
        uint256 num,
        bool isSub
    ) external returns (bool);

    function getUser(uint256 userID)
        external
        view
        returns (
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        );

    function getUserUint256Data(uint256 userID, uint256 dataID)
        external
        view
        returns (uint256);

    function setDeFiAccounts(uint256[5] calldata data) external;

    function splitDone() external;

    function getSelfInvestCount(uint256 userID)
        external
        view
        returns (uint256[5] memory selfInvestCount);

    function setSelfInvestCount(
        uint256 userID,
        uint256[5] calldata selfInvestCount
    ) external;

    function pushToInvestQueue(uint256 userID) external;

    function effectReferrals(
        uint256 userID,
        uint256 roundID,
        uint256 usdAmt,
        bool isNewUser
    ) external;

    function getLevelConfig(uint256 level, ConfigType configType)
        external
        view
        returns (uint256);

    function getUserFatherIDs(uint256 userID)
        external
        view
        returns (uint256[7] memory fathers);

    function getUserFatherActiveInfo(uint256 userID)
        external
        view
        returns (
            uint256[7] memory fathers,
            uint256[7] memory roundID,
            uint256[7] memory lastActive,
            address[7] memory addrs
        );

    function getUserFatherAddrs(uint256 userID)
        external
        view
        returns (address[7] memory fathers);

    function setGlobalBlocks(uint256[3] calldata blocks) external;

    function getGlobalNodeCount(uint256 roundID)
        external
        view
        returns (uint256[2] memory nodeCount);

    function getToken() external view returns (address);

    function setToken(address token) external;

    function getPlatformAddress() external view returns (address payable);

    function setPlatformAddress(address payable platformAddress) external;

    function getIDByAddr(address addr) external view returns (uint256);

    function getAddrByID(uint256 id) external view returns (address);

    function setUserAddr(uint256 id, address addr) external;

    function getIDByInviteCode(bytes32 inviteCode)
        external
        view
        returns (uint256);

    function getInviteCodeByID(uint256 id) external view returns (bytes32);

    function setUserInviteCode(uint256 id, bytes32 inviteCode) external;

    function issueUserID(address addr) external returns (uint256);

    function issueEventIndex() external returns (uint256);

    function setUser(
        uint256 userID,
        bool[2] calldata userBoolArry,
        uint256[21] calldata userUint256Array
    ) external;

    function deactivateUser(uint256 id) external;

    function getRound(uint256 roundID)
        external
        view
        returns (uint256[4] memory roundUint256Vars);

    function setRound(uint256 roundID, uint256[4] calldata roundUint256Vars)
        external;

    function setE2U(uint256 e2u) external;

    function setT2U(uint256 t2u) external;

    function setRoundLimit(uint256[] calldata roundID, uint256[] calldata limit)
        external;
}
