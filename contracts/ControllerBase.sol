// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ITransparentUpgradeableProxy.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./Initializable.sol";

abstract contract ControllerBase is Ownable {
    using SafeMath for uint256;

    /* struct FunctionCall {
        uint256 time;
        Func name;
        address payable addr;
        uint256 num;
        string str;
        bool boolean;
        uint256[] arr;
    } */

    uint256 numFuncCalls;

    mapping(uint256 => uint256) public time;
    mapping(uint256 => uint256) public funcIndex;
    mapping(uint256 => address payable) public addressParam;

    /*
        0 = transferNftxOwnership,

    */

    /* enum Func {
        transferAllOwnerships,
        mintRetroactively,
        redeemRetroactively,
        migrate,
        changeTokenName,
        changeTokenSymbol,
        setReverseLink,
        pause,
        unpause,
        setEligibilities,
        setController,
        setFeesArray,
        setSupplierBounty,
        setExtension
    } */

    function transferOwnership(address newOwner) public override {
        uint256 fcId = numFuncCalls;
        numFuncCalls = numFuncCalls.add(1);
        time[fcId] = now;
        funcIndex[fcId] = 0;
        addressParam[fcId] = payable(newOwner);
    }

    function initialize() public initializer {
        initOwnable();
    }

    function executeFuncCall(uint256 fcId) public virtual {
        // TODO: add time check
        if (funcIndex[fcId] == 0) {
            Ownable.transferOwnership(addressParam[fcId]);
        } 
    }
}
