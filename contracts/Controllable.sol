// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";

contract Controllable is Ownable {
    mapping(address => bool) private verifiedControllers;
    uint256 private numControllers = 0;

    event ControllerSet(address account, bool isVerified);

    function isController(address account) public view returns (bool) {
        return verifiedControllers[account];
    }

    function getNumControllers() public view returns (uint256) {
        return numControllers;
    }

    function setController(address account, bool isVerified) public onlyOwner {
        require(isVerified != verifiedControllers[account], "Already set");
        if (isVerified) {
            numControllers++;
        } else {
            numControllers--;
        }
        verifiedControllers[account] = isVerified;
        emit ControllerSet(account, isVerified);
    }

}
