// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;
// pragma experimental ABIEncoderV2;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";

contract XVaultBase is Pausable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    event NFTsDeposited(uint256 vaultId, uint256[] nftIds, address from);
    event NFTsRedeemed(uint256 vaultId, uint256[] nftIds, address to);
    event TokensMinted(uint256 vaultId, address to);
    event TokensBurned(uint256 vaultId, address from);

    struct Vault {
        address erc20Address;
        address nftAddress;
        IXToken erc20;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        EnumerableSet.UintSet reserves;
        string description;
        mapping(uint256 => bool) allowlist;
        bool negateAllowlist;
        address creator;
        bool isFinalized;
        uint256[] mintFees;
        uint256[] burnFees;
        uint256[] swapFees;
        uint256[] supplierBounty;
        uint256 status;
    }

    address public cpmAddress;
    ICryptoPunksMarket internal cpm;

    Vault[] internal vaults;

    function numVaults() public view returns (uint256) {
        return vaults.length;
    }

    function simpleRedeem(uint256 vaultId) public whenPaused nonReentrant {
        Vault storage vault = vaults[vaultId];
        require(
            vault.erc20.balanceOf(msg.sender) >= 10**18,
            "ERC20 balance too small"
        );
        require(
            vault.erc20.allowance(msg.sender, address(this)) >= 10**18,
            "ERC20 allowance too small"
        );
        uint256 nftId = vault.holdings.at(0);
        vault.erc20.burnFrom(msg.sender, 10**18);
        vault.holdings.remove(nftId);
        if (vault.nftAddress == cpmAddress) {
            cpm.transferPunk(msg.sender, nftId);
        } else {
            vault.nft.safeTransferFrom(address(this), msg.sender, nftId);
        }
        uint256[] memory nftIds;
        nftIds[0] = nftId;
        emit NFTsRedeemed(vaultId, nftIds, msg.sender);
        emit TokensBurned(vaultId, msg.sender);
    }

    function createVault(address _erc20Address, address _nftAddress)
        public
        whenNotPaused
        nonReentrant
    {
        Vault memory newVault;
        newVault.erc20Address = _erc20Address;
        newVault.nftAddress = _nftAddress;
        newVault.erc20 = IXToken(_erc20Address);
        if (_nftAddress != cpmAddress) {
            newVault.nft = IERC721(_nftAddress);
        }
    }

    /* function updateVault(
        string description,
        uint256 status,
        bool negateAllowlist
    ) public {

    } */

}
