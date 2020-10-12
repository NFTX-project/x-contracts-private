// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ICryptoPunksMarket.sol";
import "./IERC20.sol";
import "./IPunkVault.sol";

contract LinkLarvaLabs {
    address private cpmAddress;
    address private tokenAddress;
    address private vaultAddress;

    ICryptoPunksMarket private cpm;
    IERC20 private token;
    IPunkVault private vault;

    struct Offer {
        bool isForSale;
        uint256 punkIndex;
        address seller;
        uint256 minValue;
        address onlySellTo;
    }

    constructor(address _cpmAddress, address _tokenAddress, address _vaultAddress) public {
        cpmAddress = _cpmAddress;
        tokenAddress = _tokenAddress;
        vaultAddress = _vaultAddress;

        cpm = ICryptoPunksMarket(cpmAddress);
        token = IERC20(tokenAddress);
        vault = IPunkVault(vaultAddress);
    }

    function buy(uint256 punkId) public payable {
        (,,, uint256 minValue,) = cpm.punksOfferedForSale(punkId);
        require(msg.value >= minValue, "Price > payment");
        cpm.buyPunk{value: minValue}(punkId);
        cpm.transferPunk(msg.sender, punkId);
    }

    function buyMultiple(uint256[] memory punkIds, uint256[] memory prices) public payable {
        uint256 accCost = 0;
        uint256 payment = msg.value;
        for (uint256 i = 0; i < punkIds.length; i++) {
            uint256 punkId = punkIds[i];
            uint256 price = prices[i];
            (,,, uint256 minValue,) = cpm.punksOfferedForSale(punkId);
            if (minValue <= price) {
                accCost += minValue;
                require(payment >= accCost, "Value too low");
                cpm.buyPunk{value: minValue}(punkId);
                cpm.transferPunk(msg.sender, punkId);
            }
        }
        if (payment > accCost) {
            msg.sender.transfer(payment - accCost);
        }
    }

    function buyAndMint(uint256 punkId) public payable {
        (,,, uint256 minValue,) = cpm.punksOfferedForSale(punkId);
        require(msg.value >= minValue, "Price > payment");
        cpm.buyPunk{value: minValue}(punkId);
        cpm.offerPunkForSaleToAddress(punkId, 0, vaultAddress);
        uint256 bounty = vault.getMintBounty(1);
        vault.mintPunk(punkId);
        if (bounty > 0) {
            msg.sender.transfer(bounty);
        }
        token.transfer(msg.sender, 10**18);
    }

    function buyAndMintMultiple(uint256[] memory punkIds, uint256[] memory prices) public payable {
        uint256 accCost = 0;
        uint256 accBounty = 0;
        uint256 tokenCount = 0;
        uint256 payment = msg.value;
        for (uint256 i = 0; i < punkIds.length; i++) {
            uint256 punkId = punkIds[i];
            uint256 price = prices[i];
            (,,, uint256 minValue,) = cpm.punksOfferedForSale(punkId);
            if (minValue <= price) {
                accCost += minValue;
                require(payment >= accCost, "Value too low");
                cpm.buyPunk{value: minValue}(punkId);
                
                cpm.offerPunkForSaleToAddress(punkId, 0, vaultAddress);
                uint256 bounty = vault.getMintBounty(1);
                vault.mintPunk(punkId);
                accBounty += bounty;
                tokenCount += 1;
            }
        }
        if (payment > accCost) {
            msg.sender.transfer(payment - accCost);
        }
        if (accBounty > 0) {
            msg.sender.transfer(accBounty);
        }
        token.transfer(msg.sender, tokenCount*(10**18));
    }
}
