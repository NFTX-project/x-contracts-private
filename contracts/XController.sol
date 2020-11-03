// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ControllerBase.sol";
import "./INFTX.sol";
import "./IXStore.sol";
import "./Initializable.sol";

contract XController is ControllerBase {
    INFTX private nftx;
    IXStore store;

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

    /* uint256 numFuncCalls;

    mapping(uint256 => uint256) public time;
    mapping(uint256 => uint256) public funcIndex;
    mapping(uint256 => address payable) public addressParam; */
    mapping(uint256 => uint256) public uIntParam;

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

    function executeFuncCall(uint256 fcId) public override {
        // TODO: add time check
        if (funcIndex[fcId] == 0) {
            Ownable.transferOwnership(addressParam[fcId]);
        } else if (funcIndex[fcId] == 1) {
            nftx.transferOwnership(addressParam[fcId]);
        }
    }

    // TODO: a function for just increasing supplierbounty *length*
    //       - this can be used without timelock trustlessly

    function initialize(address nftxAddress) public initializer {
        initOwnable();
        nftx = INFTX(nftxAddress);
    }

    // NFTX.sol

    function changeTokenName(uint256 vaultId, string memory newName)
        public
        virtual
        onlyOwner
    /* whenNoteLockedM */
    {
        nftx.changeTokenName(vaultId, newName);
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
        virtual
        onlyOwner
    /* whenNoteLockedM */
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
    /* whenNoteLockedM */
    {
        nftx.setExtension(account, isExtension);
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    )
        public
        virtual
        onlyOwner /* whenNoteLockedM */
    {
        nftx.setMintFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    )
        public
        onlyOwner /* whenNoteLockedL */
    {
        nftx.setBurnFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    )
        public
        virtual
        onlyOwner /* whenNoteLockedM */
    {
        nftx.setDualFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    )
        public
        virtual
        onlyOwner /* whenNoteLockedL */
    {
        nftx.setSupplierBounty(vaultId, ethMax, tokenMax, length);
    }
}
