// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

interface IRandomizable {
    function getPseudoRand(uint256 modulus) external returns (uint256);
}
