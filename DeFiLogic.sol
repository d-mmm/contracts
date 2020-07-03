// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IDeFi.sol";
import "./IDeFiLogic.sol";
import "./ILast100Logic.sol";
import "./IDeFiStorage.sol";
import "./IGlobalLogic.sol";
import "./IUpgradable.sol";
import "./Common.sol";
import "./DeFiCommon.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./BytesLib.sol";


contract DeFiLogic is Common, DeFiCommon, IUpgradable, IDeFiLogic {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BytesLib for bytes;

    uint256 private constant ACTIVE_FEE = 5e5;
    uint256 private constant ACTION_ACTIVE = 1001;
    uint256 private constant AVAILABLE_BRING_OUT_PERCENT = 500;
    uint256 private constant OriginalAccountPrice = 5e15; //FIXME: 5e18
    uint256 private constant OriginalAccountPriceGrow = 5e15; // FIXME: price growth
    uint256 private constant OriginalAccountNewOpenQuota = 10; // FIXME: 10
    uint256 private constant OriginalAccountNewOpenQuotaDelayDays = 15;

    IDeFiStorage _fs;
    IGlobalLogic _gl;
    IDeFi _df;
    mapping(uint256 => uint256) private _quotas;

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

    /// internal functions
    function onTokenReceived(
        address token,
        address,
        address msgSender,
        address,
        uint256 amount,
        bytes memory userData,
        bytes memory
    ) public override onlyInternal {
        // check token
        assert(token == _fs.getToken());
        if (msgSender == address(0)) return; // mint
        // convert userData to uint256;
        uint256 userDataUint256;
        if (userData.length > 0) {
            userDataUint256 = userData.toUint256(0);
        }
        uint256 usdAmt = _fs.T2U(amount);

        if (ACTION_ACTIVE == userDataUint256) {
            assert(usdAmt == ACTIVE_FEE);
            activation(msgSender, amount, usdAmt);
            return;
        } else if (userDataUint256 > 0) {
            uint256 gear = _fs.getInvestGear(usdAmt);
            if (gear > 0) {
                invest(msgSender, userDataUint256, amount, usdAmt, gear);
                return;
            }
            revert(ERROR_UNMATCHED_PAYMENT_ACTION);
        }
    }

    function getOriginalAccountQuota()
        public
        override
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256[3] memory globalBlocks = _fs.getGlobalBlocks();
        uint256 rounds = block.number <= globalBlocks[0]
            ? 0
            : block.number.sub(globalBlocks[0]).div(
                BLOCK_PER_ROUND * OriginalAccountNewOpenQuotaDelayDays
            );
        return (
            OriginalAccountPrice.add(rounds.mul(OriginalAccountPriceGrow)),
            OriginalAccountNewOpenQuota > _quotas[rounds]
                ? OriginalAccountNewOpenQuota.sub(_quotas[rounds])
                : 0,
            rounds
        );
    }

    function register(
        address msgSender,
        uint256 msgValue,
        bytes32 inviteCode,
        bool purchaseOriginAccount
    )
        public
        override
        onlyInternal
        ensureStatus(IDeFiStorage.GlobalStatus.Pending)
    {
        require(_fs.getIDByAddr(msgSender) == 0, ERROR_USER_ALREADY_REGISTED);
        if (!purchaseOriginAccount) {
            require(inviteCode != EMPTY_BYTES32, ERROR_INVALID_INVITE_CODE);
            uint256 fatherID = _fs.getIDByInviteCode(inviteCode);
            require(fatherID != 0, ERROR_REFERRER_NOT_FOUND);
            uint256 userID = _fs.issueUserID(msgSender);
            bool[2] memory userBoolArray;
            uint256[21] memory userUint256Array;
            userUint256Array[1] = fatherID; // bind referrer
            _fs.setUser(userID, userBoolArray, userUint256Array);
            emit UserRegister(
                _fs.issueEventIndex(),
                userID,
                block.number,
                fatherID,
                msgSender
            );
        } else {
            (
                uint256 price,
                uint256 quota,
                uint256 rounds
            ) = getOriginalAccountQuota();
            require(quota > 0, ERROR_NO_ORIGINAL_ACCOUNT_QUOTA);
            _quotas[rounds]++;
            require(price <= msgValue, ERROR_ETH_NOT_ENOUGH);
            uint256 userID = _fs.issueUserID(msgSender);
            uint256[21] memory userUint256Array;
            userUint256Array[1] = ROOT_ID; // bind referrer
            emit UserRegister(
                _fs.issueEventIndex(),
                userID,
                block.number,
                ROOT_ID,
                msgSender
            );
            // issue new inviteCode
            bytes32 newInviteCode = _gl.generateInviteCode(userID);
            _fs.setUserInviteCode(userID, newInviteCode);
            // set user level
            userUint256Array[0]++;
            bool[2] memory userBoolArray;
            _fs.setUser(userID, userBoolArray, userUint256Array);
            uint256[MAX_LEVEL_DEEP + 1] memory referrers;
            uint256[MAX_LEVEL_DEEP + 1] memory amts;
            emit UserActive(
                _fs.issueEventIndex(),
                userID,
                block.number,
                referrers,
                amts,
                amts,
                newInviteCode
            );
            uint256 _stackTooDeep_msgValue = msgValue;
            emit Billing(
                _fs.issueEventIndex(),
                userID,
                block.number,
                EventAction.PurchaseOriginalAccount,
                0,
                0,
                0,
                0,
                _stackTooDeep_msgValue,
                0
            );
            _df.sendETH(_fs.getPlatformAddress(), _stackTooDeep_msgValue);
        }
    }

    function claimROI(address msgSender)
        public
        override
        onlyInternal
        ensureStatus(IDeFiStorage.GlobalStatus.Started)
    {
        _gl.internalSplitPool();
        uint256 userID = _fs.getIDByAddr(msgSender);
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
        if (
            userUint256Array[5] > 0 &&
            userUint256Array[5].add(BLOCK_PER_ROUND) > block.number
        ) revert(ERROR_TRY_AGAIN_IN_A_DAY);

        uint256 income = _fs.getLevelConfig(
            userUint256Array[3],
            IDeFiStorage.ConfigType.StaticIncomeAmt
        );
        income = income.add(userUint256Array[7]); // add dynamicIncome bringOut
        uint256 allAmt = income.add(
            _fs.getLevelConfig(
                userUint256Array[3],
                IDeFiStorage.ConfigType.InvestAmt
            )
        );
        uint256 allToken = _fs.U2T(allAmt);

        uint256 distPool;
        uint256[5] memory pools = _fs.getDeFiAccounts();
        if (pools[distPool] < allToken) {
            if (userUint256Array[4] >= 3) distPool = 1;
            else if (userUint256Array[5].add(BLOCK_PER_ROUND) <= block.number) {
                userUint256Array[4]++;
                userUint256Array[5] = block.number;
                _fs.setUser(userID, userBoolArray, userUint256Array);
                emit Error(
                    ERROR_HELPING_FUND_NOT_ENOUGH,
                    userUint256Array[4],
                    block.number
                );
                return;
            }
        }
        if (pools[distPool] < allToken) {
            // DeFi broken
            uint256[3] memory globalBlocks = _fs.getGlobalBlocks();
            globalBlocks[1] = block.number;
            _fs.setGlobalBlocks(globalBlocks);
            emit Error(ERROR_DEFI_IS_BANKRUPT, globalBlocks[1], block.number);
            return;
        }

        uint256 fee = allAmt.per(
            PERCENT_BASE,
            _fs.getLevelConfig(
                userUint256Array[3],
                IDeFiStorage.ConfigType.ClaimFeePercent
            )
        );
        uint256 distAmt = allAmt.sub(fee);
        uint256 distTokenAmt = _fs.U2T(distAmt);
        pools[distPool] = pools[distPool].sub(allToken);
        _df.sendToken(_fs.getPlatformAddress(), allToken.sub(distTokenAmt));
        _fs.setDeFiAccounts(pools);

        address _stackTooDeep_msgSender = msgSender;
        uint256 _stackTooDeep_userID2 = userID;
        // update user info
        (
            uint256 investGear,
            uint256 roundBringOut,
            uint256 roundID
        ) = _clearUserInvestmentInfo(userUint256Array, income);

        bool[2] memory _stackTooDeep_userBoolArray2 = userBoolArray;
        uint256[21] memory _stackTooDeep_userUint256Array2 = userUint256Array;
        uint256 _stackTooDeep_distTokenAmt = distTokenAmt;
        uint256 _stackTooDeep_distAmt = distAmt;
        _fs.setUser(
            _stackTooDeep_userID2,
            _stackTooDeep_userBoolArray2,
            _stackTooDeep_userUint256Array2
        );
        _df.sendToken(_stackTooDeep_msgSender, _stackTooDeep_distTokenAmt);

        uint256 _stackTooDeep_fee = fee;
        emit Billing(
            _fs.issueEventIndex(),
            _stackTooDeep_userID2,
            block.number,
            EventAction.ClaimROI,
            roundID,
            investGear,
            roundBringOut,
            _stackTooDeep_distTokenAmt,
            _stackTooDeep_distAmt,
            _stackTooDeep_fee
        );
        emit UserData(
            _fs.issueEventIndex(),
            _stackTooDeep_userID2,
            block.number,
            EventAction.ClaimROI,
            _stackTooDeep_userID2,
            0,
            _stackTooDeep_userBoolArray2,
            _stackTooDeep_userUint256Array2
        );
    }

    function deposit(
        address,
        uint256 poolID,
        uint256 tokenAmt
    ) public override onlyInternal {
        uint256[5] memory pools = _fs.getDeFiAccounts();
        pools[poolID] = pools[poolID].add(tokenAmt);
        _fs.setDeFiAccounts(pools);
    }

    /// private functions
    function activation(
        address msgSender,
        uint256 tokenAmt,
        uint256 usdAmt
    ) private ensureStatus(IDeFiStorage.GlobalStatus.Pending) {
        uint256 userID = _fs.getIDByAddr(msgSender);
        require(userID > 0, ERROR_USER_IS_NOT_REGISTED);
        require(
            _fs.getInviteCodeByID(userID) == EMPTY_BYTES32,
            ERROR_USER_ACTIVATED
        );
        // set inviteCode
        bytes32 inviteCode = _gl.generateInviteCode(userID);
        _fs.setUserInviteCode(userID, inviteCode);
        // set user level
        (
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        ) = _fs.getUser(userID);
        userUint256Array[0]++;
        _fs.setUser(userID, userBoolArray, userUint256Array);
        // dispatch activation bonus
        emit Billing(
            _fs.issueEventIndex(),
            userID,
            block.number,
            EventAction.UserActive,
            0,
            0,
            0,
            tokenAmt,
            usdAmt,
            0
        );
        uint256 balance = tokenAmt;
        uint256 usdBalance = ACTIVE_FEE;
        uint256 splitedAmt = tokenAmt.div(10);
        uint256 splitedUsdAmt = usdBalance.div(10);
        uint256[MAX_LEVEL_DEEP] memory fathers = _fs.getUserFatherIDs(userID);
        address[MAX_LEVEL_DEEP] memory fatherAddrs = _fs.getUserFatherAddrs(
            userID
        );
        uint256[MAX_LEVEL_DEEP + 1] memory referrers;
        uint256[MAX_LEVEL_DEEP + 1] memory usdAmts;
        uint256[MAX_LEVEL_DEEP + 1] memory tokenAmts;
        bool isBreak;
        for (uint256 i = 0; i <= MAX_LEVEL_DEEP && !isBreak; i++) {
            referrers[i] = (i == MAX_LEVEL_DEEP || fathers[i] == 0)
                ? ROOT_ID
                : fathers[i];
            if (referrers[i] == ROOT_ID) {
                usdAmts[i] = usdBalance;
                tokenAmts[i] = balance;
                isBreak = true;
            } else if (i == 0) {
                tokenAmts[i] = splitedAmt.mul(3);
                usdAmts[i] = splitedUsdAmt.mul(3);
            } else {
                tokenAmts[i] = splitedAmt;
                usdAmts[i] = splitedUsdAmt;
            }
            if (
                referrers[i] != ROOT_ID &&
                i != MAX_LEVEL_DEEP &&
                fatherAddrs[i] == address(0)
            ) {
                continue;
            }
            balance = balance.sub(tokenAmts[i]);
            usdBalance = usdBalance.sub(usdAmts[i]);
            _df.sendToken(
                referrers[i] == ROOT_ID
                    ? _fs.getPlatformAddress()
                    : fatherAddrs[i],
                tokenAmts[i]
            );
        }
        bytes32 _stackTooDeep_inviteCode2 = inviteCode;
        emit UserActive(
            _fs.issueEventIndex(),
            userID,
            block.number,
            referrers,
            tokenAmts,
            usdAmts,
            _stackTooDeep_inviteCode2
        );
    }

    function invest(
        address msgSender,
        uint256 roundID,
        uint256 tokenAmt,
        uint256 usdAmt,
        uint256 gear
    ) private ensureStatus(IDeFiStorage.GlobalStatus.Started) {
        uint256 userID = _fs.getIDByAddr(msgSender);
        require(userID > 0, ERROR_USER_IS_NOT_REGISTED);
        require(
            userID == ROOT_ID || _fs.getInviteCodeByID(userID) != EMPTY_BYTES32,
            ERROR_USER_IS_NOT_ACTIVATED
        );
        _gl.checkDeactiveReferrals(userID);
        (
            bool[2] memory userBoolArray,
            uint256[21] memory userUint256Array
        ) = _fs.getUser(userID);
        require(userUint256Array[6] == 0, ERROR_USER_INVESTED);
        require(
            userUint256Array[0] >= gear && userUint256Array[3] <= gear,
            ERROR_INVESTMENT_GEAR_IS_INCORRECT
        );

        bool isNewUser = userUint256Array[3] == 0;

        if (
            !_gl.checkUserAlive(
                userID,
                userUint256Array[6],
                userUint256Array[2],
                msgSender
            )
        ) {
            emit Error(ERROR_ACCOUNT_IS_DISABLED, userID, block.number);
            _df.sendToken(msgSender, tokenAmt);
            return;
        }
        updateUserInfo(
            userID,
            userUint256Array,
            isNewUser,
            roundID,
            gear,
            tokenAmt,
            usdAmt
        );

        _fs.setUser(userID, userBoolArray, userUint256Array);

        uint256[5] memory selfInvestCount;
        if (gear <= userUint256Array[0] && userUint256Array[0] < 5) {
            selfInvestCount = _fs.getSelfInvestCount(userID);
            selfInvestCount[gear - 1] = selfInvestCount[gear - 1].add(1);
            _fs.setSelfInvestCount(userID, selfInvestCount);
        }
        if (userID != ROOT_ID) _fs.pushToInvestQueue(userID);

        _fs.effectReferrals(userID, roundID, usdAmt, isNewUser);
    }

    function updateUserInfo(
        uint256 userID,
        uint256[21] memory userUint256Array,
        bool isNewUser,
        uint256 roundID,
        uint256 gear,
        uint256 tokenAmt,
        uint256 usdAmt
    ) private {
        // chech round available and update round info
        if (
            !_fs.checkRoundAvailableAndUpdate(
                isNewUser,
                roundID,
                usdAmt,
                tokenAmt
            )
        ) revert(ERROR_UNINVESTABLE);
        // update user info
        userUint256Array[2] = block.number; // lastActiveBlock
        userUint256Array[3] = gear; // maxInvestGear
        userUint256Array[6] = roundID; // investRound
        userUint256Array[9] = userUint256Array[9].add(usdAmt); // personalPerformance
        userUint256Array[7] = usdAmt.per(
            PERCENT_BASE,
            AVAILABLE_BRING_OUT_PERCENT
        ); // available bring out
        if (userUint256Array[7] > userUint256Array[8]) {
            userUint256Array[7] = userUint256Array[8];
        }
        userUint256Array[7] = userUint256Array[7].div(1e6).mul(1e6);
        emit Billing(
            _fs.issueEventIndex(),
            userID,
            block.number,
            EventAction.UserInvestment,
            roundID,
            userUint256Array[3],
            userUint256Array[7],
            tokenAmt,
            usdAmt,
            0
        );
    }

    function _clearUserInvestmentInfo(
        uint256[21] memory userUint256Array,
        uint256 income
    )
        private
        view
        returns (
            uint256 investGear,
            uint256 roundBringOut,
            uint256 roundID
        )
    {
        investGear = userUint256Array[3];
        roundBringOut = userUint256Array[7];
        userUint256Array[2] = block.number; // lastActiveBlock
        userUint256Array[4] = 0; // claimRetryCount
        userUint256Array[5] = 0; // claimRetryBlock
        roundID = userUint256Array[6];
        userUint256Array[6] = 0; // investRound
        userUint256Array[8] = userUint256Array[8].sub(userUint256Array[7]); // dynamic return balance
        userUint256Array[7] = 0; // bringOut
        userUint256Array[16] = userUint256Array[16].add(income); // invest return
    }

    /// implements functions
    function changeDependentContractAddress() public override {
        _gl = IGlobalLogic(master.getLatestAddress("GL"));
        _fs = IDeFiStorage(master.getLatestAddress("FS"));
        _df = IDeFi(master.getLatestAddress("DF"));
    }
}
