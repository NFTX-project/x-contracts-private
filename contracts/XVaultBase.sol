// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoXsMarket.sol";

contract XVaultBase is Pausable {
    struct VaultInfo {
        address erc20Address;
        address nftAddress;
    }

    IXToken private erc20;
    ICryptoXsMarket private cpm;

    function getERC20Address() public view returns (address) {
        return erc20Address;
    }

    function getCpmAddress() public view returns (address) {
        return cpmAddress;
    }

    function getERC20() internal view returns (IXToken) {
        return erc20;
    }

    function getCPM() internal view returns (ICryptoXsMarket) {
        return cpm;
    }

    function setERC20Address(address newAddress) internal {
        require(erc20Address == address(0), "Already initialized ERC20");
        erc20Address = newAddress;
        erc20 = IXToken(erc20Address);
    }

    function setCpmAddress(address newAddress) internal {
        require(cpmAddress == address(0), "Already initialized CPM");
        cpmAddress = newAddress;
        cpm = ICryptoXsMarket(cpmAddress);
    }
}
