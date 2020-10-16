// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";

contract Eligible is Ownable {
    mapping(uint256 => bool) private punkIsEligible;

    event SetEligible(uint256 punkId, bool isEligible);

    function setEligibility(uint256 punkId, bool isEligible) public onlyOwner {
        punkIsEligible[punkId] = isEligible;
        emit SetEligible(punkId, isEligible);
    }

    function setEligibilities(uint256[] memory punkIds, bool areEligible)
        public
        onlyOwner
    {
        require(punkIds.length <= 100, "Too many items");
        for (uint256 i = 0; i < punkIds.length; i++) {
            setEligibility(punkIds[i], areEligible);
        }
    }

    function isEligible(uint256 punkId) public view returns (bool) {
        return punkIsEligible[punkId];
    }
}
