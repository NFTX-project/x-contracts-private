// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

interface IEligible {
    event SetEligible(uint256 xId, bool isEligible);

    function setEligibilities(uint256[] calldata xIds, bool areEligible)
        external;
    function isEligible(uint256 xId) external view returns (bool);
    function transferOwnership(address newOwner) external;
}
