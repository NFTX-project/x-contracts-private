// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./HasCouncil.sol";
import "./SafeMath.sol";

contract Pausable is HasCouncil {
    using SafeMath for uint256;
    uint256 public pausedUntil;

    event Paused();
    event Unpaused();

    mapping(address => uint256) public remainingActions;

    modifier onlyOwnerOrPauser() {
        require(
            _msgSender() == owner() || remainingActions[_msgSender()] > 0,
            "Not owner or pauser"
        );
        _;
    }

    modifier whenNotPaused {
        require(!isPaused(), "Contract is paused");
        _;
    }

    function isPaused() public view virtual returns (bool) {
        return now < pausedUntil;
    }

    function setPaused(bool shouldPause) public virtual onlyOwnerOrPauser {
        if (remainingActions[_msgSender()] > 0) {
            remainingActions[_msgSender()] = remainingActions[_msgSender()].sub(
                1
            );
        }
        if (shouldPause) {
            pausedUntil = now + 60 * 60 * 24 * 3;
            emit Paused();
        } else {
            pausedUntil = 0;
            emit Paused();
        }
    }

    function increaseRemainingActions(address account)
        public
        virtual
        onlyOwner
    {
        remainingActions[account] = remainingActions[account].add(1);
    }

    function removeRemainingActions(address account) public virtual onlyOwner {
        remainingActions[account] = 0;
    }
}
