// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";

contract HasCouncil is Ownable {
    address public council;

    modifier onlyOwnerOrCouncil() {
        require(
            _msgSender() == owner() || _msgSender() == council,
            "Not owner or council"
        );
        _;
    }

    function setCouncil(address newCouncil) public virtual onlyOwner {
        council = newCouncil;
    }
}
