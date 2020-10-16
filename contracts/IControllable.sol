// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

interface IControllable {
    event ControllerSet(address account, bool isVerified);

    function isController(address account) external view returns (bool);
    function getNumControllers() external view returns (uint256);
    function setController(address account, bool isVerified) external;
    function transferOwnership(address newOwner) external;
}
