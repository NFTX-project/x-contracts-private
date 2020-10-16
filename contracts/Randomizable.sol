// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Controllable.sol";
import "./SafeMath.sol";

contract Randomizable {
    using SafeMath for uint256;
    uint256 private randNonce = 0;

    function getPseudoRand(uint256 modulus) public returns (uint256) {
        randNonce = randNonce.add(1);
        return
            uint256(keccak256(abi.encodePacked(now, msg.sender, randNonce))) %
            modulus;
    }
}
