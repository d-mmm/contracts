// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IUpgradable.sol";
import "./IERC777Recipient.sol";
import "./IERC1820Registry.sol";
import "./IERC20.sol";
import "./IMarketMaker.sol";
import "./IMMProtector.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";
import "./IMarketMakerLogic.sol";
import "./ReentrancyGuard.sol";

contract MarketMaker is
    IUpgradable,
    IERC777Recipient,
    IMarketMaker,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC1820Registry internal ERC1820 = IERC1820Registry(
        0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24
    );
    bytes32 internal constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256(
        "ERC777TokensRecipient"
    );

    IMMProtector private _mp;
    IMarketMakerLogic private _ml;

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
        _ml.onTokenReceived(
            msg.sender,
            operator,
            from,
            to,
            amount,
            userData,
            operatorData
        );
    }

    receive() external payable {
        _ml.buyToken(msg.sender, msg.value, msg.data);
    }

    /// public functions
    function deposit(uint256 amt) public payable {
        require(msg.value == amt,'ETH amount not equal');
    }

    function buyToken() public payable {
        _ml.buyToken(msg.sender, msg.value, msg.data);
    }

    function buyTokenFromERC20(address token, uint256 amt) public {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        _ml.buyTokenFromERC20(msg.sender, token, amt);
    }

    function getTradeStatus() public view returns (bool[2] memory) {
        return _mp.getTradeStatus();
    }

    function _sendToken(
        address token,
        address to,
        uint256 amt
    ) private nonReentrant {
        IERC20(token).safeTransfer(to, amt);
    }

    function _sendETH(address payable to, uint256 amt) private nonReentrant {
        to.transfer(amt);
    }

    // internal functions
    function sendToken(
        address token,
        address to,
        uint256 amt
    ) public override onlyInternal {
        _sendToken(token, to, amt);
    }

    function sendETH(address payable to, uint256 amt)
        public
        override
        onlyInternal
    {
        _sendETH(to, amt);
    }

    /// implements functions
    function changeDependentContractAddress() public override {
        _mp = IMMProtector(master.getLatestAddress("MP"));
        _ml = IMarketMakerLogic(master.getLatestAddress("ML"));
    }
}
