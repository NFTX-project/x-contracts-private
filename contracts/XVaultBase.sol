// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";
import "./IXUtils.sol";
import "./SafeMath.sol";

contract XVaultBase is Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    event NFTsDeposited(uint256 vaultId, uint256[] nftIds, address from);
    event NFTsRedeemed(uint256 vaultId, uint256[] nftIds, address to);
    event TokensMinted(uint256 vaultId, uint256 amount, address to);
    event TokensBurned(uint256 vaultId, uint256 amount, address from);

    event EligibilitySet(uint256 vaultId, uint256[] nftIds, bool _boolean);
    event ReservesIncreased(uint256 vaultId, uint256 nftId);
    event ReservesDecreased(uint256 vaultId, uint256 nftId);

    //TODO: add ethBalanceIncreased / Decreased + other events

    struct Vault {
        address erc20Address;
        address nftAddress;
        IXToken erc20;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        EnumerableSet.UintSet reserves;
        string description;
        mapping(uint256 => bool) isEligible;
        mapping(uint256 => bool) shouldReserve;
        bool negateEligibility;
        address creator;
        bool isFinalized;
        bool isApproved;
        bool isClosed;
        uint256[] mintFees;
        uint256[] burnFees;
        uint256[] swapFees;
        uint256[] supplierBounty;
        uint256 ethBalance;
    }

    Vault[] internal vaults;

    address public cpmAddress;
    address public xUtilsAddress;

    ICryptoPunksMarket internal cpm;
    IXUtils internal xUtils;

    mapping(address => bool) public isIntegrator;

    // Modifiers -----------------------------------------------//

    modifier onlyIntegrator() {
        require(isIntegrator[_msgSender()], "Not integrator");
        _;
    }

    // Getters -------------------------------------------------//

    function numVaults() public view returns (uint256) {
        return vaults.length;
    }

    function isEligible(uint256 vaultId, uint256 nftId)
        public
        view
        returns (bool)
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        if (vaults[vaultId].negateEligibility) {
            return !vaults[vaultId].isEligible[nftId];
        } else {
            return vaults[vaultId].isEligible[nftId];
        }
    }

    function vaultSize(vaultId) public view returns (uint256) {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        return vault.holdings.length() + vault.reserves.length();
    }

    // Management ----------------------------------------------//

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

    function depositETH(uint256 vaultId) public payable {
        vaults[vaultId].ethBalance = vaults[vaultId].ethBalance.add(msg.value);
    }

    // onlyOwner -----------------------------------------------//

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyOwner {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.isEligible[nftIds[i]] = _boolean;
        }
        emit EligibilitySet(vaultId, nftIds, _boolean);
    }

    function setShouldReserve(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyOwner {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.shouldReserve[nftIds[i]] = _boolean;
        }
    }

    function setIsReserved(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyOwner {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            if (_boolean) {
                require(vault.holdings.contains(nftId), "Invalid nftId");
                vault.holdings.remove(nftId);
                vault.reserves.add(nftId);
                emit ReservesIncreased(vaultId, nftId);
            } else {
                require(vault.reserves.contains(nftId), "Invalid nftId");
                vault.reserves.remove(nftId);
                vault.holdings.add(nftId);
                emit ReservesDecreased(vaultId, nftId);
            }
        }
    }

    function setIsIntegrator(address contractAddress, bool _boolean)
        public
        onlyOwner
    {
        isIntegrator[contractAddress] = _boolean;
    }

    // Internal ------------------------------------------------//

    function _mint(uint256 vaultId, uint256[] memory nftIds, bool isSwap)
        internal
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            require(isEligible(vaultId, nftId), "Not eligible");
            if (vault.nftAddress == cpmAddress) {
                cpm.buyPunk(nftId);
            } else {
                require(
                    vault.nft.ownerOf(nftId) != address(this),
                    "Already owner"
                );
                vault.nft.safeTransferFrom(_msgSender(), address(this), nftId);
                require(
                    vault.nft.ownerOf(nftId) == address(this),
                    "Not received"
                );
            }
        }
        emit NFTsDeposited(vaultId, nftIds, _msgSender());
        if (!isSwap) {
            uint256 amount = nftIds.length * (10**18);
            vault.erc20.mint(_msgSender(), amount);
            emit TokensMinted(vaultId, amount, _msgSender());
        }
    }

    function _redeem(uint256 vaultId, uint256 numNFTs, bool isSwap) internal {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        uint256[] memory nftIds;
        for (uint256 i = 0; i < numNFTs; i++) {
            if (vault.holdings.length() > 0) {
                uint256 rand = xUtils.getPseudoRand(vault.holdings.length());
                nftIds[i] = vault.holdings.at(rand);
            } else {
                uint256 rand = xUtils.getPseudoRand(vault.reserves.length());
                nftIds[i] = vault.reserves.at(rand);
            }
        }
        _directRedeem(vaultId, nftIds, _msgSender(), isSwap);
    }

    function _directRedeem(
        uint256 vaultId,
        uint256[] memory nftIds,
        address sender,
        bool isSwap
    ) internal {
        Vault storage vault = vaults[vaultId];
        require(vaultId < vaults.length, "Invalid vaultId");
        if (!isSwap) {
            require(
                vault.erc20.balanceOf(sender) >= nftIds.length * 10**18,
                "ERC20 balance too small"
            );
            require(
                vault.erc20.allowance(sender, address(this)) >=
                    nftIds.length * 10**18,
                "ERC20 allowance too small"
            );
            vault.erc20.burnFrom(sender, nftIds.length * 10**18);
            emit TokensBurned(vaultId, 10**18, sender);
        }
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            require(
                vault.holdings.contains(nftId) ||
                    vault.reserves.contains(nftId),
                "NFT not in vault"
            );
            if (vault.holdings.contains(nftId)) {
                vault.holdings.remove(nftId);
            } else {
                vault.reserves.remove(nftId);
                emit ReservesDecreased(vaultId, nftId);
            }
            if (vault.nftAddress == cpmAddress) {
                cpm.transferPunk(sender, nftId);
            } else {
                vault.nft.safeTransferFrom(address(this), sender, nftId);
            }
        }
        emit NFTsRedeemed(vaultId, nftIds, sender);
    }

    // onlyIntegrator ------------------------------------------//

    function directRedeem(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        nonReentrant
        onlyIntegrator
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        uint256 burnBounty = xUtils.calcBurnBounty(
            nftIds.length,
            vault.holdings.length() + vault.reserves.length(),
            vault.supplierBounty
        );
        require(msg.value >= burnBounty, "Value too low");
        vault.ethBalance = vault.ethBalance.add(burnBounty);
        _directRedeem(vaultId, nftIds, _msgSender(), false);
    }

    // whenPaused ----------------------------------------------//

    // function simpleRedeem(uint256 vaultId, uint256 numNFTs)
    //     public
    //     whenPaused
    //     nonReentrant
    // {
    //     require(vaultId < vaults.length, "Invalid vaultId");
    //     uint256[] memory nftIds;
    //     if (vault.holdings.lenght() > 0) {}
    //     nftIds[0] = vaults[vaultId].holdings.at(0);
    //     _redeem(vaultId, numNFTs, false);
    //     _directRedeem(vaultId, nftIds, _msgSender(), false);
    // }

    // public --------------------------------------------------//

    function mint(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        require(!vault.isClosed, "Vault is closed");
        uint256 bounty = xUtils.calcMintBounty(
            nftIds.length,
            vaultSize(vaultId),
            vault.supplierBounty
        );
        uint256 fee = xUtils.calcFee(nftIds.length, vault.mintFees);
        if (fee > bounty) {
            require(msg.value >= fee - bounty, "Value too low");
        }
        _mint(vaultId, nftIds, false);
        if (bounty > fee) {
            uint256 payout = bounty - fee;
            if (vault.ethBalance >= payout) {
                _msgSender().transfer(payout);
            } else if (vault.ethBalance > 0) {
                _msgSender().transfer(vault.ethBalance);
            }
        }
    }

    function redeem(uint256 vaultId, uint256 numNFTs) public payable nonReentrant {
        require(vaultId < vaults.length, "Invalid vaultId");
        Vault storage vault = vaults[vaultId];
        if (!getIsPaused() && !vault.isClosed) {
            uint256 bounty = xUtils.calcBurnBounty(
                numNFTs, 
                vaultSize(vaultId), 
                vault.supplierBounty
            );
            uint256 fee = xUtils.calcFee(numNFTs, vault.burnFees);
            if (bounty.add(fee) > 0) {
                require(msg.value >= bounty.add(fee), "Value too low");
            }
        }
        _redeem(vaultId, numNFTs, false);
    }

    // TODO: swap

}
