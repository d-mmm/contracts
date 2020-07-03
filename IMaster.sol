// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IMaster {
    function isOwner(address _addr) external view returns (bool);

    function payableOwner() external view returns (address payable);

    function isInternal(address _addr) external view returns (bool);

    function getLatestAddress(bytes2 _contractName)
        external
        view
        returns (address contractAddress);
}
