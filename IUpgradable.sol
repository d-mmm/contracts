// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IMaster.sol";
import "./Address.sol";

abstract contract IUpgradable {
    IMaster public master;

    modifier onlyInternal {
        assert(master.isInternal(msg.sender));
        _;
    }

    modifier onlyOwner {
        assert(master.isOwner(msg.sender));
        _;
    }

    modifier onlyMaster {
        assert(address(master) == msg.sender);
        _;
    }

    /**
     * @dev IUpgradable Interface to update dependent contract address
     */
    function changeDependentContractAddress() public virtual;

    /**
     * @dev change master address
     * @param addr is the new address
     */
    function changeMasterAddress(address addr) public {
        assert(Address.isContract(addr));
        assert(address(master) == address(0) || address(master) == msg.sender);
        master = IMaster(addr);
    }
}
