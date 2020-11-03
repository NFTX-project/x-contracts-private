// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Timelocked.sol";
import "./INFTX.sol";

contract XController is Timelocked {
    INFTX private nftx;

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
            
        } else if (funcIndex[fcId] == 2) {

        } else if (funcIndex[fcId] == 3) {

        } else if (funcIndex[fcId] == 4) {
            
        } else if (funcIndex[fcId] == 5) {

        } else if (funcIndex[fcId] == 6) {
            
        } else if (funcIndex[fcId] == 7) {

        } else if (funcIndex[fcId] == 8) {
            
        } else if (funcIndex[fcId] == 9) {

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
        nftx = INFTX(nftxAddress);
    }

    // NFTX.sol

    function changeTokenName(uint256 vaultId, string memory newName)
        public
        virtual
        onlyOwner
        whenNotLockedM
    {
        nftx.changeTokenName(vaultId, newName);
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
        virtual
        onlyOwner
        whenNotLockedM
    {
        nftx.changeTokenSymbol(vaultId, newSymbol);
    }

    function setPaused(bool shouldPause) public virtual onlyOwner {
        nftx.setPaused(shouldPause);
    }

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool areEligible
    ) public virtual onlyOwner {
        nftx.setIsEligible(vaultId, nftIds, areEligible);
    }

    function setExtension(address account, bool isExtension)
        public
        virtual
        onlyOwner
        whenNotLockedM
    {
        nftx.setExtension(account, isExtension);
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public virtual onlyOwner whenNotLockedM {
        nftx.setMintFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyOwner whenNotLockedL {
        nftx.setBurnFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public virtual onlyOwner whenNotLockedM {
        nftx.setDualFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    ) public virtual onlyOwner whenNotLockedL {
        nftx.setSupplierBounty(vaultId, ethMax, tokenMax, length);
    }
}
