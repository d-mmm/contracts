// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./SafeERC20.sol";
import "./IERC20.sol";
import "./IERC1820Registry.sol";
import "./IERC777Recipient.sol";
import "./SafeMath.sol";
import "./ReentrancyGuard.sol";

contract TokenExchange is IERC777Recipient, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 _newToken;
    IERC20 _oldToken;

    IERC1820Registry internal _ERC1820 = IERC1820Registry(
        0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24
    );
    bytes32 internal constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256(
        "ERC777TokensRecipient"
    );

    constructor(address newTokenAddr) public {
        _newToken = IERC20(newTokenAddr);
        _oldToken = IERC20(0xF453Ac18fa17b9eC9a76fbF219Ba9fe4612eDd0a);
        _ERC1820.setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
    }

    function tokensReceived(
        address,
        address from,
        address, //to
        uint256 amt,
        bytes calldata,
        bytes calldata
    ) external override nonReentrant {
        if (from == address(0)) {
            assert(msg.sender == address(_newToken));
            return;
        }
        assert(msg.sender == address(_oldToken));
        _newToken.safeTransfer(from, amt);
    }
}
