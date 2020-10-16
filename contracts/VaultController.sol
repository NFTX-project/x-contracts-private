// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Timelocked.sol";
import "./IPunkVault.sol";
import "./IEligible.sol";
import "./IRandomizable.sol";
import "./IControllable.sol";
import "./IProfitable.sol";

contract VaultController is Timelocked {
    IPunkVault private vault;
    IEligible internal eligibleContract;
    IControllable internal controllableContract;
    IProfitable internal profitableContract;

    FunctionCall[] private callArray;

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

    struct FunctionCall {
        uint256 time;
        Func name;
        address payable addr;
        uint256 num;
        string str;
        bool boolean;
        uint256[] arr;
    }
    // TODO: add array for list of params and calls to make

    constructor(
        address vaultAddress,
        address eligibleAddress,
        address controllableAddress,
        address profitableAddress
    ) public {
        vault = IPunkVault(vaultAddress);
        eligibleContract = IEligible(eligibleAddress);
        controllableContract = IControllable(controllableAddress);
        profitableContract = IProfitable(profitableAddress);
    }

    function transferAllOwnerships(address newOwner)
        public
        onlyOwner
        whenNotLockedL
    {
        vault.transferOwnership(newOwner);
        eligibleContract.transferOwnership(newOwner);
        controllableContract.transferOwnership(newOwner);
        profitableContract.transferOwnership(newOwner);
    }

    // PunkVault.sol

    function mintRetroactively(uint256 tokenId, address to)
        public
        onlyOwner
        whenNotLockedS
    {
        vault.mintRetroactively(tokenId, to);
    }

    function redeemRetroactively(address to) public onlyOwner whenNotLockedS {
        vault.redeemRetroactively(to);
    }

    function migrate(address to, uint256 max) public onlyOwner whenNotLockedL {
        vault.migrate(to, max);
    }

    function changeTokenName(string memory newName)
        public
        onlyOwner
        whenNotLockedM
    {
        vault.changeTokenName(newName);
    }

    function changeTokenSymbol(string memory newSymbol)
        public
        onlyOwner
        whenNotLockedM
    {
        vault.changeTokenSymbol(newSymbol);
    }

    function setReverseLink() public onlyOwner {
        vault.setReverseLink();
    }

    function withdraw(address payable to) public onlyOwner whenNotLockedM {
        vault.withdraw(to);
    }

    // Pausable.sol

    function pause() public onlyOwner {
        vault.pause();
    }

    function unpause() public onlyOwner {
        vault.unpause();
    }

    function setEligibilities(uint256[] memory punkIds, bool areEligible)
        public
        onlyOwner
    {
        eligibleContract.setEligibilities(punkIds, areEligible);
    }

    // Controllable.sol

    function setController(address account, bool isVerified) public onlyOwner {
        controllableContract.setController(account, isVerified);
    }

    // Profitable.sol

    function setFeesArray(IProfitable.FeeType feeType, uint256[] memory newFees)
        public
        onlyOwner
    {
        profitableContract.setFeesArray(feeType, newFees);
    }

    function setSupplierBounty(uint256[] memory newSupplierBounty)
        public
        onlyOwner
    {
        profitableContract.setSupplierBounty(newSupplierBounty);
    }

    function setIntegrator(address account, bool isVerified) public onlyOwner {
        profitableContract.setIntegrator(account, isVerified);
    }

}
