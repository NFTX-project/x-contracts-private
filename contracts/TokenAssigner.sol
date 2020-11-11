// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ITokenManager.sol";

contract TokenAssigner {
    ITokenManager public tokenManager;

    constructor(address tokenManagerAddress) public {
        tokenManager = ITokenManager(tokenManagerAddress);
    }

    /* function callMint(address _receiver, uint256 _amount) public {
        tokenManager.mint(_receiver, _amount);
    } */

    function callIssue(uint256 _amount) public {
        tokenManager.issue(_amount);
    }

    function callAssignVested(
        address _receiver,
        uint256 _amount,
        uint64 _start,
        uint64 _cliff,
        uint64 _vested,
        bool _revokable
    ) public returns (uint256) {
        return
            tokenManager.assignVested(
                _receiver,
                _amount,
                _start,
                _cliff,
                _vested,
                _revokable
            );
    }
}
