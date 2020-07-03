// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./ERC777.sol";
import "./Ownable.sol";

contract Token is ERC777, Ownable {
    // FIXME: max supply limit
    uint256 public constant _maxSupply = 0;
    // uint256 public constant _maxSupply = 5 * (10**8) * (10**18);

    modifier noOverflow(uint256 _amt) {
        require(
            _maxSupply == 0 || _maxSupply >= totalSupply().add(_amt),
            "totalSupply overflow"
        );
        _;
    }

    constructor() public ERC777("dMMM", "dMMM", new address[](0)) {
        return;
    }

    function mint(address _address, uint256 _amount)
        public
        noOverflow(_amount)
        onlyOwner
    {
        _mint(_address, _amount, "", "");
    }
}
