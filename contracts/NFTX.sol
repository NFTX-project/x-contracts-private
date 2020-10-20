// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";

contract NFTX is Pausable, ReentrancyGuard {
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

    struct FeeParams {
        uint256 ethBase;
        uint256 ethStep;
        uint256 tokenShare;
    }

    struct BountyParams {
        uint256 ethMax;
        uint256 tokenMax;
        uint256 length;
    }

    struct Vault {
        address erc20Address;
        address nftAddress;
        address manager;
        IXToken erc20;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        EnumerableSet.UintSet reserves;
        string description;
        mapping(uint256 => bool) isEligible;
        mapping(uint256 => bool) shouldReserve;
        bool negateEligibility;
        bool isFinalized;
        bool isClosed;
        FeeParams mintFees;
        FeeParams burnFees;
        FeeParams dualFees;
        BountyParams supplierBounty;
        uint256 ethBalance;
        uint256 tokenBalance;
    }

    Vault[] internal vaults;

    address public cpmAddress;
    ICryptoPunksMarket internal cpm;

    mapping(address => bool) public isIntegrator;

    constructor(address _cpmAddress) public {
        cpmAddress = _cpmAddress;
        cpm = ICryptoPunksMarket(cpmAddress);
    }

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

    function vaultSize(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.length() + vault.reserves.length();
    }

    // Utils ----------------------------------------------------//

    uint256 private randNonce = 0;

    function _getPseudoRand(uint256 modulus) internal returns (uint256) {
        randNonce = randNonce.add(1);
        return
            uint256(keccak256(abi.encodePacked(now, msg.sender, randNonce))) %
            modulus;
    }

    function _calcFee(uint256 numTokens, FeeParams storage feeP)
        internal
        view
        returns (uint256, uint256)
    {
        if (numTokens == 0) {
            return (0, 0);
        } else {
            return (
                feeP.ethBase.add(feeP.ethStep.mul(numTokens.sub(1))),
                feeP.tokenShare.mul(numTokens)
            );
        }
    }

    function _calcBounty(uint256 vaultId, uint256 numTokens, bool isBurn)
        public
        view
        returns (uint256, uint256)
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        uint256 ethBounty = 0;
        uint256 tokenBounty = 0;
        for (uint256 i = 0; i < numTokens; i = i.add(1)) {
            uint256 index = isBurn
                ? vaultSize(vaultId).sub(i).add(1)
                : vaultSize(vaultId).add(i);
            (uint256 _ethBounty, uint256 _tokenBounty) = _calcBountyHelper(
                vaultId,
                index
            );
            ethBounty = ethBounty.add(_ethBounty);
            tokenBounty = tokenBounty.add(_tokenBounty);
        }
        return (ethBounty, tokenBounty);
    }

    function _calcBountyHelper(uint256 vaultId, uint256 index)
        internal
        view
        returns (uint256, uint256)
    {
        BountyParams storage bp = vaults[vaultId].supplierBounty;
        if (vaultSize(vaultId) > bp.length) {
            return (0, 0);
        }
        uint256 depth = bp.length.sub(vaultSize(vaultId));
        return (
            bp.ethMax.div(bp.length).mul(depth),
            bp.tokenMax.div(bp.length).mul(depth)
        );
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
        _getVault(vaultId).ethBalance = vaults[vaultId].ethBalance.add(
            msg.value
        );
    }

    function setIsIntegrator(address contractAddress, bool _boolean)
        public
        onlyOwner
    {
        isIntegrator[contractAddress] = _boolean;
    }

    // Internal ------------------------------------------------//

    function _payEthFromVault(
        uint256 vaultId,
        uint256 amount,
        address payable to
    ) internal {
        Vault storage vault = _getVault(vaultId);
        uint256 amountToSend;
        if (vault.ethBalance >= amount) {
            amountToSend = amount;
        } else if (vault.ethBalance > 0) {
            amountToSend = vault.ethBalance;
        }
        if (amountToSend > 0) {
            vault.ethBalance = vault.ethBalance.sub(amountToSend);
            to.transfer(amountToSend);
        }
    }

    function _payTokenFromVault(
        uint256 vaultId,
        uint256 amount,
        address payable to
    ) internal {
        Vault storage vault = _getVault(vaultId);
        uint256 amountToSend;
        if (vault.tokenBalance >= amount) {
            amountToSend = amount;
        } else if (vault.tokenBalance > 0) {
            amountToSend = vault.tokenBalance;
        }
        if (amountToSend > 0) {
            vault.tokenBalance = vault.tokenBalance.sub(amountToSend);
            vault.erc20.transfer(to, amountToSend);
        }
    }

    function _receiveEthForVault(
        uint256 vaultId,
        uint256 amountRequested,
        uint256 amountSent
    ) internal {
        require(amountSent >= amountRequested, "Value too low");
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = vault.ethBalance.add(amountRequested);
    }

    function _receiveTokenForVault(
        uint256 vaultId,
        uint256 amountRequested,
        address sender
    ) internal {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.transferFrom(sender, address(this), amountRequested);
        vault.tokenBalance = vault.tokenBalance.add(amountRequested);
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds, bool isDualOp)
        internal
    {
        Vault storage vault = _getVault(vaultId);
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
        if (!isDualOp) {
            uint256 amount = nftIds.length * (10**18);
            vault.erc20.mint(_msgSender(), amount);
            emit TokensMinted(vaultId, amount, _msgSender());
        }
    }

    function _redeem(uint256 vaultId, uint256 numNFTs, bool isDualOp) internal {
        Vault storage vault = _getVault(vaultId);
        uint256[] memory nftIds;
        for (uint256 i = 0; i < numNFTs; i++) {
            if (vault.holdings.length() > 0) {
                uint256 rand = _getPseudoRand(vault.holdings.length());
                nftIds[i] = vault.holdings.at(rand);
            } else {
                uint256 rand = _getPseudoRand(vault.reserves.length());
                nftIds[i] = vault.reserves.at(rand);
            }
        }
        _directRedeem(vaultId, nftIds, _msgSender(), isDualOp);
    }

    function _directRedeem(
        uint256 vaultId,
        uint256[] memory nftIds,
        address sender,
        bool isDualOp
    ) internal {
        Vault storage vault = _getVault(vaultId);
        if (!isDualOp) {
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

    function _onlyOwnerOrManager(uint256 vaultId) internal view {
        Vault storage vault = _getVault(vaultId);
        if (vault.isFinalized) {
            require(_msgSender() == owner(), "Not owner");
        } else {
            require(_msgSender() == vault.manager, "Not manager");
        }
    }

    function _getVault(uint256 vaultId) internal view returns (Vault storage) {
        require(vaultId < vaults.length, "Invalid vaultId");
        return vaults[vaultId];
    }

    // onlyIntegrator ------------------------------------------//

    function directRedeem(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        nonReentrant
        onlyIntegrator
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        (uint256 ethBounty, uint256 tokenBounty) = _calcBounty(
            vaultId,
            nftIds.length,
            true
        );
        _receiveEthForVault(vaultId, ethBounty, msg.value);
        _receiveTokenForVault(vaultId, tokenBounty, _msgSender());
        _directRedeem(vaultId, nftIds, _msgSender(), false);
    }

    // public --------------------------------------------------//

    function mint(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        require(!vault.isClosed, "Vault is closed");
        (uint256 ethBounty, uint256 tokenBounty) = _calcBounty(
            vaultId,
            nftIds.length,
            false
        );
        (uint256 ethFee, uint256 tokenFee) = _calcFee(
            nftIds.length,
            vault.mintFees
        );
        if (ethFee > ethBounty) {
            _receiveEthForVault(vaultId, ethFee.sub(ethBounty), msg.value);
        }
        if (tokenFee > tokenBounty) {
            _receiveTokenForVault(
                vaultId,
                tokenFee.sub(tokenBounty),
                _msgSender()
            );
        }
        _mint(vaultId, nftIds, false);
        if (ethBounty > ethFee) {
            _payEthFromVault(vaultId, ethBounty.sub(ethFee), _msgSender());

        }
        if (tokenBounty > tokenFee) {
            _payTokenFromVault(
                vaultId,
                tokenBounty.sub(tokenFee),
                _msgSender()
            );
        }
    }

    function redeem(uint256 vaultId, uint256 numTokens)
        public
        payable
        nonReentrant
    {
        Vault storage vault = _getVault(vaultId);
        if (!getIsPaused() && !vault.isClosed) {
            (uint256 ethBounty, uint256 tokenBounty) = _calcBounty(
                vaultId,
                numTokens,
                true
            );
            (uint256 ethFee, uint256 tokenFee) = _calcFee(
                numTokens,
                vault.burnFees
            );
            if (ethBounty.add(ethFee) > 0) {
                _receiveEthForVault(vaultId, ethBounty.add(ethFee), msg.value);
            }
            if (tokenBounty.add(tokenFee) > 0) {
                _receiveTokenForVault(
                    vaultId,
                    tokenBounty.add(tokenFee),
                    _msgSender()
                );
            }
        }
        _redeem(vaultId, numTokens, false);
    }

    function mintAndRedeem(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        require(!vault.isClosed, "Vault is closed");
        (uint256 ethFee, uint256 tokenFee) = _calcFee(
            nftIds.length,
            vault.dualFees
        );
        if (ethFee > 0) {
            _receiveEthForVault(vaultId, ethFee, msg.value);
        }
        if (tokenFee > 0) {
            _receiveTokenForVault(vaultId, tokenFee, _msgSender());
        }
        _mint(vaultId, nftIds, true);
        _redeem(vaultId, nftIds.length, true);
    }

    // onlyOwnerOrManager ------------------------------------------//

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);

        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.isEligible[nftIds[i]] = _boolean;
        }
        emit EligibilitySet(vaultId, nftIds, _boolean);
    }

    function setNegateEligibility(uint256 vaultId, bool shouldNegate) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.negateEligibility = shouldNegate;
    }

    function setShouldReserve(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.shouldReserve[nftIds[i]] = _boolean;
        }
    }

    function setIsReserved(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
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

    function changeTokenName(uint256 vaultId, string memory newName) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.erc20.changeName(newName);
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
    {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.erc20.changeSymbol(newSymbol);
    }

    function withdrawFromVault(uint256 vaultId, uint256 amount) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        if (vault.ethBalance >= amount) {
            _msgSender().transfer(amount);
            vault.ethBalance = vault.ethBalance.sub(amount);
        } else {
            _msgSender().transfer(vault.ethBalance);
            vault.ethBalance = 0;
        }
    }

    function finalizeVault(uint256 vaultId) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.isFinalized = true;
    }

    function closeVault(uint256 vaultId) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.isClosed = true;
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.mintFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.burnFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.dualFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    ) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.supplierBounty = BountyParams(ethMax, tokenMax, length);
    }

    function setManager(uint256 vaultId, address newManager) public {
        Vault storage vault = _getVault(vaultId);
        _onlyOwnerOrManager(vaultId);
        vault.manager = newManager;
    }

    // onlyOwner ---------------------------------------------------//

    function migrate(uint256 vaultId, uint256 limit, address to)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        uint256 count;
        while (vault.holdings.length() + vault.reserves.length() > 0) {
            if (count >= limit) {
                return;
            }
            uint256 nftId;
            if (vault.holdings.length() > 0) {
                nftId = vault.holdings.at(0);
                vault.holdings.remove(nftId);
            } else {
                nftId = vault.reserves.at(0);
                vault.reserves.remove(nftId);
            }
            if (vault.nftAddress == cpmAddress) {
                cpm.transferPunk(to, nftId);
            } else {
                vault.nft.safeTransferFrom(address(this), to, nftId);
            }
            count = count.add(1);
        }
    }

    function withdraw(uint256 amount, address payable to) public onlyOwner {
        to.transfer(amount);
    }

}
