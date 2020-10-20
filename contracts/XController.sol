// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Timelocked.sol";
import "./INFTX.sol";

contract XController is Timelocked {
    INFTX private nftx;
    FunctionCall[] private callArray;

    struct FunctionCall {
        uint256 time;
        Func name;
        address payable addr;
        uint256 num;
        string str;
        bool boolean;
        uint256[] arr;
    }

    enum Func {
        transferAllOwnerships,
        mintRetroactively,
        redeemRetroactively,
        migrate,
        changeTokenName,
        changeTokenSymbol,
        setReverseLink,
        withdraw,
        pause,
        unpause,
        setEligibilities,
        setController,
        setFeesArray,
        setSupplierBounty,
        setIntegrator
    } // TODO: add funcs for setting timelock times

    // TODO: add array for list of params and calls to make

    constructor(address nftxAddress) public {
        nftx = INFTX(nftxAddress);
    }

    function transferAllOwnerships(address newOwner)
        public
        onlyOwner
        whenNotLockedL
    {
        nftx.transferOwnership(newOwner);
    }

    // NFTX.sol

    function migrate(uint256 vaultId, uint256 max, address to)
        public
        onlyOwner
        whenNotLockedL
    {
        nftx.migrate(vaultId, max, to);
    }

    function changeTokenName(uint256 vaultId, string memory newName)
        public
        onlyOwner
        whenNotLockedM
    {
        nftx.changeTokenName(vaultId, newName);
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
        onlyOwner
        whenNotLockedM
    {
        nftx.changeTokenSymbol(vaultId, newSymbol);
    }

    function withdraw(uint256 amount, address payable to)
        public
        onlyOwner
        whenNotLockedL
    {
        nftx.withdraw(amount, to);
    }

    function pause() public onlyOwner {
        nftx.pause();
    }

    function unpause() public onlyOwner {
        nftx.unpause();
    }

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool areEligible
    ) public onlyOwner {
        nftx.setIsEligible(vaultId, nftIds, areEligible);
    }

    function setIntegrator(address account, bool isIntegrator)
        public
        onlyOwner
    {
        nftx.setIsIntegrator(account, isIntegrator);
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyOwner {
        nftx.setMintFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyOwner {
        nftx.setBurnFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyOwner {
        nftx.setDualFees(vaultId, _ethBase, _ethStep, _tokenShare);
    }

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    ) public onlyOwner {
        nftx.setSupplierBounty(vaultId, ethMax, tokenMax, length);
    }
}
