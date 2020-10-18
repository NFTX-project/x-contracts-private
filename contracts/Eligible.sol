// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";

contract Eligible is Ownable {
    mapping(uint256 => bool) private xIsEligible;

    event SetEligible(uint256 xId, bool isEligible);

    function setEligibilities(uint256[] memory xIds, bool areEligible)
        public
        onlyOwner
    {
        require(xIds.length <= 100, "Too many items");
        for (uint256 i = 0; i < xIds.length; i++) {
            xIsEligible[xIds[i]] = areEligible;
            emit SetEligible(xIds[i], areEligible);
        }
    }

    function isEligible(uint256 xId) public view returns (bool) {
        return xIsEligible[xId];
    }
}
