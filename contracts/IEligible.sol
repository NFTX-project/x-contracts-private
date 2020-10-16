// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

interface IEligible {
    event SetEligible(uint256 punkId, bool isEligible);

    function setEligibility(uint256 punkId, bool isEligible) external;
    function setEligibilities(uint256[] calldata punkIds, bool areEligible)
        external;
    function isEligible(uint256 punkId) external view returns (bool);
    function transferOwnership(address newOwner) external;
}
