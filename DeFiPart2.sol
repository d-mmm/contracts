// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IDeFi.sol";
import "./IDeFiStorage.sol";
import "./IGlobalLogic.sol";
import "./IDeFiLogic.sol";
import "./ILast100Logic.sol";
import "./IUpgradable.sol";
import "./DeFiCommon.sol";
import "./SafeMath.sol";

contract DeFiPart2 is IUpgradable, DeFiCommon {
    using SafeMath for uint256;

    uint256 private constant MAX_SAVE_NODE_BONUS_DAYS = 10;

    /// events
    enum UserStatus {PendingRegister, PendingActive, Active, Waiting, Claim}
    event AccountTransfer(
        uint256 indexed eventID,
        uint256 indexed userID,
        uint256 blockNumber,
        address oldAddr,
        address newAddr
    );

    IDeFi _df;
    IGlobalLogic _gl;
    IDeFiLogic _dl;
    ILast100Logic _ll;
    IDeFiStorage private _fs;

    modifier ensureStatus(IDeFiStorage.GlobalStatus requireStatus) {
        IDeFiStorage.GlobalStatus status = _fs.getGlobalStatus();
        require(
            status == requireStatus ||
                (requireStatus == IDeFiStorage.GlobalStatus.Pending &&
                    (status == IDeFiStorage.GlobalStatus.Pending ||
                        status == IDeFiStorage.GlobalStatus.Started)),
            ERROR_INVALID_STATUS
        );
        _;
    }

    /// public functions
    function getNodeBonusBalance(uint256 nodeID)
        public
        view
        returns (uint256[2] memory balance)
    {
        (, uint256[21] memory userUint256Array) = _fs.getUser(nodeID);
        if (userUint256Array[19] > 0)
            (balance[0], ) = _getAllNodeBonus(
                nodeID,
                userUint256Array[14],
                0,
                0,
                false,
                true
            );
        if (userUint256Array[20] > 0)
            (balance[1], ) = _getAllNodeBonus(
                nodeID,
                userUint256Array[15],
                0,
                0,
                true,
                true
            );
    }

    function getAvailableRound(bool isNewUser)
        public
        view
        returns (
            uint256 optionAID,
            IDeFiStorage.InvestType optionAType,
            uint256 optionBID,
            uint256 optionBDelay,
            IDeFiStorage.InvestType optionBType
        )
    {
        uint256 currentRoundID = _fs.getCurrentRoundID(false);
        (optionAID, optionAType) = _fs.getAvailableRoundID(isNewUser, false);
        if (optionAID == 0 || optionAType == IDeFiStorage.InvestType.PreOrder) {
            for (uint256 i = 1; i <= ROUND_ALLOW_PREORDER; i++) {
                uint256 innerRoundID = currentRoundID.add(
                    i.mul(BLOCK_PER_ROUND)
                );
                uint256[4] memory roundUint256Vars = _fs.getRound(innerRoundID);
                if (roundUint256Vars[1] == 0) {
                    break;
                }
                // skip round lgt available round
                if (innerRoundID == optionAID) break;
                // for new user
                if (roundUint256Vars[0] < roundUint256Vars[1]) {
                    if (isNewUser) {
                        optionBID = innerRoundID;
                        uint256 temp = innerRoundID.sub(BLOCK_PER_ROUND).sub(
                            NEWBIE_BLOCKS
                        );
                        optionBDelay = temp > block.number
                            ? temp.sub(block.number)
                            : 0;
                        optionBType = IDeFiStorage.InvestType.Newbie;
                    } else {
                        optionBID = innerRoundID;
                        uint256 temp = innerRoundID.sub(BLOCK_PER_ROUND);
                        optionBDelay = temp > block.number
                            ? temp.sub(block.number)
                            : 0;
                        optionBType = IDeFiStorage.InvestType.Open;
                    }
                    break;
                }
            }
        }
    }

    function getUser()
        public
        view
        returns (
            UserStatus status,
            bytes32 inviteCode,
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        )
    {
        uint256 userID = _fs.getIDByAddr(msg.sender);
        if (userID == 0) {
            status = UserStatus.PendingRegister;
            return (status, inviteCode, userBoolArray, userUint256Array);
        }
        inviteCode = _fs.getInviteCodeByID(userID);
        if (userID != ROOT_ID && inviteCode == EMPTY_BYTES32) {
            status = UserStatus.PendingActive;
            return (status, inviteCode, userBoolArray, userUint256Array);
        }
        (userBoolArray, userUint256Array) = _fs.getUser(userID);
        if (userUint256Array[6] == 0) {
            status = UserStatus.Active;
            return (status, inviteCode, userBoolArray, userUint256Array);
        }
        if (
            block.number.sub(BLOCK_PER_ROUND * DELAY_ROUND) >
            userUint256Array[6]
        ) {
            status = UserStatus.Claim;
            return (status, inviteCode, userBoolArray, userUint256Array);
        }
        status = UserStatus.Waiting;
        return (status, inviteCode, userBoolArray, userUint256Array);
    }

    function getNodeBonusEachRound(
        uint256 roundID,
        uint256 userID,
        bool isSuperNode
    )
        public
        view
        returns (
            uint256 usdAmt,
            uint256 liteMarketPerformance,
            uint256 totalPerformance
        )
    {
        (, uint256[21] memory userUint256Vars) = _fs.getUser(userID);
        uint256[4] memory roundUint256Vars = _fs.getRound(roundID);
        uint256 cursor = userUint256Vars[isSuperNode ? 20 : 19];
        if (cursor == 0 || roundID < cursor) {
            return (0, 0, roundUint256Vars[isSuperNode ? 3 : 2]);
        }
        (uint256[6] memory poolSplitPercent, uint256[2] memory nodeCount) = _fs
            .getPoolSplitPercent(roundID);
        return
            _getNodeBonusEachRound(
                roundID,
                userID,
                poolSplitPercent[isSuperNode ? 4 : 3],
                nodeCount[isSuperNode ? 1 : 0],
                isSuperNode
            );
    }

    function transferAccount(address newAddr) public {
        assert(newAddr != address(0));
        uint256 userID = _fs.getIDByAddr(msg.sender);
        require(userID > 0, ERROR_USER_IS_NOT_REGISTED);
        require(_fs.getIDByAddr(newAddr) == 0, ERROR_USER_ALREADY_REGISTED);
        _fs.setUserAddr(userID, newAddr);
        emit AccountTransfer(
            _fs.issueEventIndex(),
            userID,
            block.number,
            msg.sender,
            newAddr
        );
    }

    function claimNodeBonus()
        public
        ensureStatus(IDeFiStorage.GlobalStatus.Started)
    {
        _claimNodeBonus(false);
    }

    function claimSuperNodeBonus()
        public
        ensureStatus(IDeFiStorage.GlobalStatus.Started)
    {
        _claimNodeBonus(true);
    }

    function claimCompensation()
        public
        ensureStatus(IDeFiStorage.GlobalStatus.Bankruptcy)
    {
        uint256 userID = _fs.getIDByAddr(msg.sender);
        require(userID > 0, ERROR_USER_IS_NOT_REGISTED);
        (
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        ) = _fs.getUser(userID);
        require(userUint256Array[6] > 0, ERROR_USER_HAS_NOT_INVESTED);
        require(
            block.number.sub(BLOCK_PER_ROUND * DELAY_ROUND) >
                userUint256Array[6],
            ERROR_ROUND_IS_NOT_OVER
        );

        userBoolArray[0] = true; // receivedBankruptcyCompensation
        uint256 investAmt = _fs.getLevelConfig(
            userUint256Array[3],
            IDeFiStorage.ConfigType.InvestAmt
        );
        uint256 totalIncomeAmt = userUint256Array[16]
            .add(userUint256Array[17])
            .add(userUint256Array[18]);
        uint256 distAmt = totalIncomeAmt > investAmt
            ? 0
            : investAmt.sub(totalIncomeAmt);
        uint256 tokenAmt = _fs.U2T(distAmt);

        uint256[5] memory pools = _fs.getDeFiAccounts();
        pools[2] = pools[2].sub(tokenAmt);
        _fs.setDeFiAccounts(pools);

        // update user info
        userUint256Array[2] = block.number; // lastActiveBlock
        userUint256Array[4] = 0; // claimRetryCount
        userUint256Array[5] = 0; // claimRetryBlock
        uint256 roundID = userUint256Array[6];
        userUint256Array[6] = 0; // investRound
        userUint256Array[7] = 0; // bringOut

        _fs.setUser(userID, userBoolArray, userUint256Array);
        _df.sendToken(msg.sender, tokenAmt);

        emit UserData(
            _fs.issueEventIndex(),
            userID,
            block.number,
            EventAction.ClaimCompensation,
            userID,
            0,
            userBoolArray,
            userUint256Array
        );
        emit Billing(
            _fs.issueEventIndex(),
            userID,
            block.number,
            EventAction.ClaimCompensation,
            roundID,
            0,
            0,
            tokenAmt,
            distAmt,
            0
        );
    }

    /// private functions
    function _getNodeBonusEachRound(
        uint256 roundID,
        uint256 userID,
        uint256 poolSpliPercent,
        uint256 nodeCount,
        bool isSuperNode
    )
        private
        view
        returns (
            uint256 usdAmt,
            uint256 liteMarketPerformance,
            uint256 totalPerformance
        )
    {
        assert(roundID > 0 && userID > 0);
        uint256[4] memory roundUint256Vars = _fs.getRound(roundID);
        uint256 nodePerformance = _fs.getNodePerformance(
            roundID,
            userID,
            isSuperNode
        );
        uint256 averageDividend = nodeCount > 0
            ? roundUint256Vars[0].mul(poolSpliPercent).div(
                PERCENT_BASE * 2 * nodeCount
            )
            : 0;
        uint256 weightedDividend = roundUint256Vars[isSuperNode ? 3 : 2] > 0
            ? roundUint256Vars[0]
                .mul(poolSpliPercent * nodePerformance)
                .div(PERCENT_BASE * 2)
                .div(roundUint256Vars[isSuperNode ? 3 : 2])
            : 0;
        return (
            averageDividend.add(weightedDividend),
            nodePerformance,
            roundUint256Vars[isSuperNode ? 3 : 2]
        );
    }

    function _claimNodeBonus(bool isSuperNode) private {
        _gl.internalSplitPool();
        _ll.internalExchange();
        uint256 userID = _fs.getIDByAddr(msg.sender);
        require(userID > 0, ERROR_USER_IS_NOT_REGISTED);
        (
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        ) = _fs.getUser(userID);
        uint256 lastClaimType = isSuperNode ? 15 : 14;
        require(
            userUint256Array[lastClaimType] > 0,
            isSuperNode ? ERROR_USER_IS_NOT_NODE : ERROR_USER_IS_NOT_SUPER_NODE
        );

        if (
            !_gl.checkUserAlive(
                userID,
                userUint256Array[6],
                userUint256Array[2],
                msg.sender
            )
        ) {
            emit Error(ERROR_ACCOUNT_IS_DISABLED, userID, block.number);
            return;
        }

        uint256[5] memory pools = _fs.getDeFiAccounts();
        uint256 oneUSDWeiToToken = _fs.U2T(1);

        (uint256 allBonus, uint256 endCursor) = _getAllNodeBonus(
            userID,
            userUint256Array[lastClaimType],
            pools[isSuperNode ? 4 : 3],
            oneUSDWeiToToken,
            isSuperNode,
            false
        );

        require(allBonus > 0, ERROR_NO_MORE_BONUS);

        uint256 fee = allBonus.per(
            PERCENT_BASE,
            _fs.getLevelConfig(
                isSuperNode ? 7 : 6,
                IDeFiStorage.ConfigType.ClaimFeePercent
            )
        );

        uint256 distUsdAmt = allBonus.sub(fee);
        uint256 distTokenAmt = oneUSDWeiToToken.mul(distUsdAmt);

        emit Billing(
            _fs.issueEventIndex(),
            userID,
            block.number,
            isSuperNode
                ? EventAction.ClaimSuperNodeBonus
                : EventAction.ClaimNodeBonus,
            userUint256Array[lastClaimType],
            0,
            0,
            distTokenAmt,
            distUsdAmt,
            fee
        );

        userUint256Array[lastClaimType] = endCursor; // last claim node bonus
        userUint256Array[isSuperNode ? 18 : 17] = userUint256Array[isSuperNode
            ? 18
            : 17]
            .add(allBonus); // node bouns
        uint256 _stackTooDeep_userID2 = userID;
        bool _stackTooDeep_isSuperNode = isSuperNode;
        bool[2] memory _stackTooDeep_userBoolArray2 = userBoolArray;
        uint256[21] memory _stackTooDeep_userUint256Array2 = userUint256Array;
        uint256 allTokenAmt = oneUSDWeiToToken.mul(allBonus);
        pools[_stackTooDeep_isSuperNode
            ? 4
            : 3] = pools[_stackTooDeep_isSuperNode ? 4 : 3].sub(allTokenAmt);
        _fs.setUser(
            _stackTooDeep_userID2,
            _stackTooDeep_userBoolArray2,
            _stackTooDeep_userUint256Array2
        );
        _fs.setDeFiAccounts(pools);
        _df.sendToken(_fs.getPlatformAddress(), allTokenAmt.sub(distTokenAmt));
        _df.sendToken(_fs.getAddrByID(_stackTooDeep_userID2), distTokenAmt);

        emit UserData(
            _fs.issueEventIndex(),
            _stackTooDeep_userID2,
            block.number,
            EventAction.ClaimNodeBonus,
            _stackTooDeep_userID2,
            0,
            _stackTooDeep_userBoolArray2,
            _stackTooDeep_userUint256Array2
        );
    }

    function _getAllNodeBonus(
        uint256 userID,
        uint256 cursor,
        uint256 poolBalance,
        uint256 oneUSDWeiToToken,
        bool isSuperNode,
        bool getAll
    ) private view returns (uint256 allBonus, uint256 endCursor) {
        uint256 currentRoundID = _fs.getCurrentRoundID(!getAll);
        endCursor = cursor;
        if (
            endCursor <
            currentRoundID.sub(BLOCK_PER_ROUND * MAX_SAVE_NODE_BONUS_DAYS)
        ) {
            endCursor = currentRoundID.sub(
                BLOCK_PER_ROUND * MAX_SAVE_NODE_BONUS_DAYS
            );
        }
        while (endCursor < currentRoundID) {
            (
                uint256[6] memory poolSplitPercent,
                uint256[2] memory nodeCount
            ) = _fs.getPoolSplitPercent(endCursor);
            (uint256 roundBonus, , ) = _getNodeBonusEachRound(
                endCursor,
                userID,
                poolSplitPercent[isSuperNode ? 4 : 3],
                nodeCount[isSuperNode ? 1 : 0],
                isSuperNode
            );
            if (
                !getAll &&
                poolBalance < oneUSDWeiToToken.mul(allBonus.add(roundBonus))
            ) {
                break;
            } else {
                allBonus = allBonus.add(roundBonus);
                endCursor = endCursor.add(BLOCK_PER_ROUND);
            }
        }
    }

    /// implements functions
    function changeDependentContractAddress() public override {
        _fs = IDeFiStorage(master.getLatestAddress("FS"));
        _gl = IGlobalLogic(master.getLatestAddress("GL"));
        _dl = IDeFiLogic(master.getLatestAddress("DL"));
        _df = IDeFi(master.getLatestAddress("DF"));
        _ll = ILast100Logic(master.getLatestAddress("LL"));
    }
}
