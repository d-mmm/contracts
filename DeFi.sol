// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IDeFi.sol";
import "./IDeFiStorage.sol";
import "./IDeFiLogic.sol";
import "./IERC777Recipient.sol";
import "./IERC1820Registry.sol";
import "./IERC20.sol";
import "./IUpgradable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";


contract DeFi is IUpgradable, IDeFi, IERC777Recipient, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 internal constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256(
        "ERC777TokensRecipient"
    );
    IERC1820Registry internal ERC1820 = IERC1820Registry(
        0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24
    );
    IDeFiStorage _fs;
    IDeFiLogic _dl;

    constructor() public {
        ERC1820.setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
    }

    /// fallback
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) public override {
        _dl.onTokenReceived(
            msg.sender,
            operator,
            from,
            to,
            amount,
            userData,
            operatorData
        );
    }

    /// public functions
    function getOriginalAccountQuota()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return _dl.getOriginalAccountQuota();
    }

    function register(bytes32 inviteCode, bool purchaseOriginAccount)
        public
        payable
    {
        _dl.register(msg.sender, msg.value, inviteCode, purchaseOriginAccount);
    }

    function claimROI() public {
        _dl.claimROI(msg.sender);
    }

    function deposit(uint256 poolID, uint256 tokenAmt) public {
        IERC20(_fs.getToken()).safeTransferFrom(
            msg.sender,
            address(this),
            tokenAmt
        );
        _dl.deposit(msg.sender, poolID, tokenAmt);
    }

    function sendToken(address to, uint256 amt)
        public
        override
        onlyInternal
        nonReentrant
    {
        IERC20(_fs.getToken()).safeTransfer(to, amt);
    }

    function sendETH(address payable to, uint256 amt)
        public
        override
        onlyInternal
        nonReentrant
    {
        to.transfer(amt);
    }

    /// implements functions
    function changeDependentContractAddress() public override {
        _fs = IDeFiStorage(master.getLatestAddress("FS"));
        _dl = IDeFiLogic(master.getLatestAddress("DL"));
    }
}
