// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "./IMaster.sol";
import "./IUpgradable.sol";
import "./Ownable.sol";
import "./Address.sol";

contract Master is IMaster, Ownable {
    bool private constructorCheck;
    bytes2[] private allContractNames;
    mapping(address => bool) private contractsActive;
    mapping(bytes2 => address payable) private allContractVersions;

    IUpgradable up;

    constructor() public {
        contractsActive[address(this)] = true;
        _addContractNames();
    }

    function masterInitialized() public view returns (bool) {
        return constructorCheck;
    }

    function initContracts(address payable[] memory _contractAddresses)
        public
        onlyOwner
    {
        assert(!constructorCheck);
        assert(_contractAddresses.length == allContractNames.length);
        constructorCheck = true;

        for (uint256 i = 0; i < allContractNames.length; i++) {
            assert(Address.isContract(_contractAddresses[i]));
            allContractVersions[allContractNames[i]] = _contractAddresses[i];
        }

        changeMasterAddress(address(this));
        _changeAllAddress();
    }

    function payableOwner() public override view returns (address payable) {
        address payable addr = address(uint160(owner()));
        return addr;
    }

    function isOwner(address _addr) public override view returns (bool) {
        return owner() == _addr;
    }

    function isInternal(address _add) public override view returns (bool) {
        return contractsActive[_add];
    }

    function getLatestAddress(bytes2 _contractName)
        public
        override
        view
        returns (address)
    {
        return allContractVersions[_contractName];
    }

    function addContract(bytes2 name, address payable addr) public onlyOwner {
        require(
            allContractVersions[name] == address(0),
            "contract already exits"
        );
        allContractNames.push(name);
        upgradeContract(name, addr);
    }

    function deleteContract(bytes2 name) public onlyOwner {
        for (uint256 i = 0; i < allContractNames.length; i++) {
            if (allContractNames[i] == name) {
                delete allContractNames[i];
                address addr = allContractVersions[name];
                delete allContractVersions[name];
                delete contractsActive[addr];
                return;
            }
        }
        revert("non such contract");
    }

    function upgradeContract(
        bytes2 _contractsName,
        address payable _contractsAddress
    ) public onlyOwner {
        assert(Address.isContract(_contractsAddress));
        assert(
            _validContractName(_contractsName) &&
                contractsActive[allContractVersions[_contractsName]]
        );
        address payable oldAddr = allContractVersions[_contractsName];
        allContractVersions[_contractsName] = _contractsAddress;
        contractsActive[oldAddr] = false;

        up = IUpgradable(_contractsAddress);
        up.changeMasterAddress(address(this));

        _changeAllAddress();
    }

    function changeMasterAddress(address _masterAddr) public onlyOwner {
        Master newMaster = Master(_masterAddr);
        assert(newMaster.masterInitialized());

        for (uint256 i = 0; i < allContractNames.length; i++) {
            up = IUpgradable(allContractVersions[allContractNames[i]]);
            up.changeMasterAddress(_masterAddr);
        }

        contractsActive[address(this)] = false;
        contractsActive[_masterAddr] = true;
    }

    function _changeAllAddress() private {
        for (uint256 i = 0; i < allContractNames.length; i++) {
            contractsActive[allContractVersions[allContractNames[i]]] = true;
            up = IUpgradable(allContractVersions[allContractNames[i]]);
            up.changeDependentContractAddress();
        }
    }

    function _validContractName(bytes2 name) private view returns (bool) {
        for (uint256 i = 0; i < allContractNames.length; i++) {
            if (name == allContractNames[i]) {
                return true;
            }
        }
        return false;
    }

    function _addContractNames() private {
        allContractNames.push("DF"); // DeFi
        allContractNames.push("D2"); // FeFi part2
        allContractNames.push("DL"); // DeFi logic
        allContractNames.push("GL"); // Global logic
        allContractNames.push("MM"); // MarketMaker
        allContractNames.push("ML"); // MarketMaker logic
        allContractNames.push("MP"); // MarketMaker Protector
        allContractNames.push("LB"); // last100 bonus
        allContractNames.push("LL"); // Last100 logic
        allContractNames.push("FS"); // DeFi storage
    }
}
