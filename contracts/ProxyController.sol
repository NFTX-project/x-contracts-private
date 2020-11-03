// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Timelocked.sol";
import "./ITransparentUpgradeableProxy.sol";

contract ProxyController is Timelocked {

    ITransparentUpgradeableProxy private nftxProxy;
    ITransparentUpgradeableProxy private controllerProxy;

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

    function executeFuncCall(uint256 fcId) public {
        if (funcIndex[fcId] == 0) {
            Ownable.transferOwnership(addressParam[fcId]);
        } else if (funcIndex[fcId] == 1) {
            nftxProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 2) {
            nftxProxy.upgradeTo(addressParam[fcId]);
        } else if (funcIndex[fcId] == 3) {
            controllerProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 4) {
            controllerProxy.upgradeTo(addressParam[fcId]);
        } 
    }

    function transferOwnership(address newOwner) public override {
        uint256 fcId = numFuncCalls;
        numFuncCalls = numFuncCalls.add(1);
        time[fcId] = now;
        funcIndex[fcId] = 0;
        addressParam[fcId] = payable(newOwner);
    }

    function initialize(address nftxAddress) public {
        nftxProxy = ITransparentUpgradeableProxy(nftxAddress);
        controllerProxy = ITransparentUpgradeableProxy(
            address(this)
        );
    }

   }
