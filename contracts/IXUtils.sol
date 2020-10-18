// SPDX-License-Identifier: MIT

import "./SafeMath.sol";

pragma solidity >=0.6.0 <0.7.0;

interface IXUtils {
    // using SafeMath for uint256;
    enum FeeType {Mint, Burn, Swap}
    // uint256 private randNonce = 0;

    function getPseudoRand(uint256 modulus) external returns (uint256);

    function calcFee(uint256 numTokens, uint256[] calldata fees)
        external
        pure
        returns (uint256);

    function calcBurnBounty(uint256 numTokens, uint256 vaultSize, uint256[] calldata supplierBounty)
        external
        pure
        returns (uint256);

    function calcMintBounty(uint256 numTokens, uint256 reservesLength, uint256[] calldata supplierBounty)
        external
        pure
        returns (uint256);
}
