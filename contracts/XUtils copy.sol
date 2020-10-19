// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

import "./Ownable.sol";
import "./SafeMath.sol";

contract XIntegrations is Ownable {
    using SafeMath for uint256;

    mapping(address => bool) public isIntegration;

    function setIsIntegration(address contractAddress, bool _boolean)
        public
        onlyOwner
    {
        isIntegration[contractAddress] = _boolean;
    }
}
