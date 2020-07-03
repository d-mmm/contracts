// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

contract Common {
    // configs
    bytes32 internal EMPTY_BYTES32;
    uint256 internal constant PERCENT_BASE = 1000;
    uint256 internal constant ROOT_ID = 6666;
    uint256 internal constant MAX_LEVEL_DEEP = 7;
    uint256 internal constant BLOCK_PER_ROUND = 96; // FIXME: 5760
    uint256 internal constant DELAY_ROUND = 4; // FIXME: 10
    uint256 internal constant ROUND_ALLOW_PREORDER = 15; // FIXME: 15
    uint256 internal constant NEWBIE_BLOCKS = 12;
    uint256 internal constant ROUND_PREORDER_LIMIT_PERCENT = 700;

    // error codes
    string constant ERROR_HELPING_FUND_NOT_ENOUGH = "1"; // helpingFund not enough
    string constant ERROR_DEFI_IS_BANKRUPT = "2"; // defi is bankrupt
    string constant ERROR_ACCOUNT_IS_DISABLED = "3"; // account is disabled
    string constant ERROR_UNINVESTABLE = "4"; // The investable quota is full
    string constant ERROR_INVALID_STATUS = "5"; // invalid status
    string constant ERROR_INVALID_INVITE_CODE = "6"; // invalid inviteCode
    string constant ERROR_REFERRER_NOT_FOUND = "7"; // Referrer not found
    string constant ERROR_USER_ALREADY_REGISTED = "8"; // user already registed
    string constant ERROR_USER_IS_NOT_REGISTED = "9"; // user is not registed
    string constant ERROR_USER_HAS_NOT_INVESTED = "10"; // User has not invested
    string constant ERROR_ROUND_IS_NOT_OVER = "11"; // Round is not over
    string constant ERROR_TRY_AGAIN_IN_A_DAY = "12"; // Try again in a day
    string constant ERROR_USER_ACTIVATED = "13"; // User activated
    string constant ERROR_USER_IS_NOT_ACTIVATED = "14"; // User is not activated
    string constant ERROR_USER_INVESTED = "15"; // User invested
    string constant ERROR_INVESTMENT_GEAR_IS_INCORRECT = "16"; // Investment gear is incorrect
    string constant ERROR_USER_IS_NOT_NODE = "17"; // user is not node
    string constant ERROR_USER_IS_NOT_SUPER_NODE = "18"; // user is not super node
    string constant ERROR_NO_MORE_BONUS = "19"; // no more bonus
    string constant ERROR_ALREADY_CLAIMED = "20"; // already claimed
    string constant ERROR_NOT_IN_LAST100 = "21"; // not in last 100 users
    string constant ERROR_NO_ORIGINAL_ACCOUNT_QUOTA = "22"; // no original account quota
    string constant ERROR_ETH_NOT_ENOUGH = "23"; // ETH not enough
    string constant ERROR_TOKEN_NOT_ENOUGH = "24"; // Token not enough
    string constant ERROR_UNMATCHED_PAYMENT_ACTION = "25"; // Unmatched payment action

    enum EventAction {
        Unknown,
        PurchaseOriginalAccount,
        UserActive,
        UserInvestment,
        ReferralUserInvestment,
        ClaimROI,
        ClaimCompensation,
        ClaimNodeBonus,
        ClaimSuperNodeBonus,
        ClaimLast100Bonus
    }

    event UserRegister(
        uint256 indexed eventID,
        uint256 indexed userID,
        uint256 blockNumber,
        uint256 referralUserID,
        address userAddr
    );

    event UserActive(
        uint256 indexed eventID,
        uint256 indexed userID,
        uint256 blockNumber,
        uint256[MAX_LEVEL_DEEP + 1] referrers,
        uint256[MAX_LEVEL_DEEP + 1] tokenAmts,
        uint256[MAX_LEVEL_DEEP + 1] usdAmts,
        bytes32 inviteCode
    );

    event Billing(
        uint256 indexed eventID,
        uint256 indexed userID,
        uint256 blockNumber,
        EventAction action,
        uint256 extData,
        uint256 extData1,
        uint256 extData2,
        uint256 tokenAmt,
        uint256 usdAmt,
        uint256 feeUSD
    );

    event UserData(
        uint256 indexed eventID,
        uint256 indexed userID,
        uint256 blockNumber,
        EventAction action,
        uint256 fromUserID,
        uint256 extData,
        bool[2] userBoolArray,
        uint256[21] userUint256Array
    );

    event RoundData(
        uint256 indexed eventID,
        uint256 indexed roundID,
        uint256 blockNumber,
        uint256[4] roundUint256Vars
    );

    // FIXME: debug function
    function uint2str(uint256 i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        uint256 _i = i;
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}
