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

    function transferAllOwnerships(address newOwner) public onlyOwner {
        vault.transferOwnership(newOwner);
        eligibleContract.transferOwnership(newOwner);
        controllableContract.transferOwnership(newOwner);
        profitableContract.transferOwnership(newOwner);
    }

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

    function pause() public onlyOwner {
        vault.pause();
    }

    function unpause() public onlyOwner {
        vault.unpause();
    }
}
