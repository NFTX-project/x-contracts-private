// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";
import "./SafeMath.sol";

contract Pausable is Ownable {
    bool isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "Paused");
        _;
    }

    function setPaused(bool _isPaused) public virtual onlyOwner {
        isPaused = _isPaused;
    }
}
