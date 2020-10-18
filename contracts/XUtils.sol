// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

import "./Ownable.sol";
import "./SafeMath.sol";

contract XUtils {
    using SafeMath for uint256;
    enum FeeType {Mint, Burn, Swap}
    uint256 private randNonce = 0;

    function getPseudoRand(uint256 modulus) public returns (uint256) {
        randNonce = randNonce.add(1);
        return
            uint256(keccak256(abi.encodePacked(now, msg.sender, randNonce))) %
            modulus;
    }

    function calcFee(uint256 numTokens, uint256[] memory fees)
        public
        pure
        returns (uint256)
    {
        if (numTokens == 1) {
            return fees[0];
        } else {
            return fees[1] + numTokens * fees[2];
        }
    }

    function calcBurnBounty(uint256 numTokens, uint256 vaultSize, uint256[] memory supplierBounty)
        public
        pure
        returns (uint256)
    {
        uint256 bounty = 0;
        uint256 padding = supplierBounty[1];
        if (vaultSize - numTokens <= padding) {
            uint256 addedAmount = 0;
            for (uint256 i = 0; i < numTokens; i++) {
                if (vaultSize - i <= padding && vaultSize - i > 0) {
                    addedAmount += (supplierBounty[0] *
                        (padding - (vaultSize - i) + 1));
                }
            }
            bounty += addedAmount;
        }
        return bounty;
    }

    function calcMintBounty(uint256 numTokens, uint256 reservesLength, uint256[] memory supplierBounty)
        public
        pure
        returns (uint256)
    {
        uint256 bounty = 0;
        uint256 padding = supplierBounty[1];
        if (reservesLength <= padding) {
            uint256 addedAmount = 0;
            for (uint256 i = 0; i < numTokens; i++) {
                if (reservesLength + i <= padding) {
                    addedAmount += (supplierBounty[0] *
                        (padding - (reservesLength + i)));
                }
            }
            bounty += addedAmount;
        }
        return bounty;
    }
}
