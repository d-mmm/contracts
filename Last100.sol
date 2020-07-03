// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IDeFiStorage.sol";
import "./IUpgradable.sol";
import "./ILast100.sol";
import "./ILast100Logic.sol";
import "./IERC20.sol";
import "./IERC1820Registry.sol";
import "./IERC777Recipient.sol";
import "./Common.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

contract Last100 is
    IUpgradable,
    Common,
    IERC777Recipient,
    ILast100,
    ReentrancyGuard
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 internal constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256(
        "ERC777TokensRecipient"
    );
    IERC1820Registry internal ERC1820 = IERC1820Registry(
        0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24
    );

    IDeFiStorage private _fs;
    ILast100Logic private _ll;
    uint256 totalBonus;

    constructor() public {
        ERC1820.setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
    }

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

    receive() external payable {
        return;
    }

    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes memory,
        bytes memory
    ) public override {
        // check token
        assert(msg.sender == _fs.getToken());
    }

    /// public functions
    function claimLast100Bonus()
        public
        ensureStatus(IDeFiStorage.GlobalStatus.Bankruptcy)
    {
        uint256 userID = _ll.checkUserAvailable(msg.sender);
        if (totalBonus == 0) totalBonus = address(this).balance;
        _sendETH(msg.sender, totalBonus.div(100));
        emit Billing(
            _fs.issueEventIndex(),
            userID,
            block.number,
            EventAction.ClaimLast100Bonus,
            0,
            0,
            0,
            totalBonus.div(100),
            0,
            0
        );
    }

    /// internal functions
    function sendToken(address to, uint256 amt) public override onlyInternal {
        _sendToken(to, amt);
    }

    function sendETH(address payable to, uint256 amt)
        public
        override
        onlyInternal
    {
        _sendETH(to, amt);
    }

    /// private functions
    function _sendETH(address payable to, uint256 amt) private nonReentrant {
        to.transfer(amt);
    }

    function _sendToken(address to, uint256 amt) private nonReentrant {
        IERC20(_fs.getToken()).safeTransfer(to, amt);
    }

    /// implements functions
    function changeDependentContractAddress() public override {
        _fs = IDeFiStorage(master.getLatestAddress("FS"));
        _ll = ILast100Logic(master.getLatestAddress("LL"));
    }
}
