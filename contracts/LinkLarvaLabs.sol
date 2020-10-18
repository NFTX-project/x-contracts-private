// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ICryptoXsMarket.sol";
import "./IERC20.sol";
import "./IXVault.sol";

contract LinkLarvaLabs {
    address private cpmAddress;
    address private tokenAddress;
    address private vaultAddress;

    ICryptoXsMarket private cpm;
    IERC20 private token;
    IXVault private vault;

    struct Offer {
        bool isForSale;
        uint256 xIndex;
        address seller;
        uint256 minValue;
        address onlySellTo;
    }

    constructor(address _cpmAddress, address _tokenAddress, address _vaultAddress) public {
        cpmAddress = _cpmAddress;
        tokenAddress = _tokenAddress;
        vaultAddress = _vaultAddress;

        cpm = ICryptoXsMarket(cpmAddress);
        token = IERC20(tokenAddress);
        vault = IXVault(vaultAddress);
    }

    function buy(uint256 xId) public payable {
        (,,, uint256 minValue,) = cpm.xsOfferedForSale(xId);
        require(msg.value >= minValue, "Price > payment");
        cpm.buyX{value: minValue}(xId);
        cpm.transferX(msg.sender, xId);
    }

    function buyMultiple(uint256[] memory xIds, uint256[] memory prices) public payable {
        uint256 accCost = 0;
        uint256 payment = msg.value;
        for (uint256 i = 0; i < xIds.length; i++) {
            uint256 xId = xIds[i];
            uint256 price = prices[i];
            (,,, uint256 minValue,) = cpm.xsOfferedForSale(xId);
            if (minValue <= price) {
                accCost += minValue;
                require(payment >= accCost, "Value too low");
                cpm.buyX{value: minValue}(xId);
                cpm.transferX(msg.sender, xId);
            }
        }
        if (payment > accCost) {
            msg.sender.transfer(payment - accCost);
        }
    }

    function buyAndMint(uint256 xId) public payable {
        (,,, uint256 minValue,) = cpm.xsOfferedForSale(xId);
        require(msg.value >= minValue, "Price > payment");
        cpm.buyX{value: minValue}(xId);
        cpm.offerXForSaleToAddress(xId, 0, vaultAddress);
        uint256 bounty = vault.getMintBounty(1);
        vault.mintX(xId);
        if (bounty > 0) {
            msg.sender.transfer(bounty);
        }
        token.transfer(msg.sender, 10**18);
    }

    function buyAndMintMultiple(uint256[] memory xIds, uint256[] memory prices) public payable {
        uint256 accCost = 0;
        uint256 accBounty = 0;
        uint256 tokenCount = 0;
        uint256 payment = msg.value;
        for (uint256 i = 0; i < xIds.length; i++) {
            uint256 xId = xIds[i];
            uint256 price = prices[i];
            (,,, uint256 minValue,) = cpm.xsOfferedForSale(xId);
            if (minValue <= price) {
                accCost += minValue;
                require(payment >= accCost, "Value too low");
                cpm.buyX{value: minValue}(xId);
                
                cpm.offerXForSaleToAddress(xId, 0, vaultAddress);
                uint256 bounty = vault.getMintBounty(1);
                vault.mintX(xId);
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
