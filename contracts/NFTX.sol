// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";
import "./ERC721Holder.sol";
import "./SafeMath.sol";
import "./utils/console.sol";

contract NFTX is Pausable, ReentrancyGuard, ERC721Holder {
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

    struct D2Weighting {
        uint256 vaultId;
        uint256 weighting;
    }

    struct Vault {
        address erc20Address;
        address assetAddress;
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
        bool isD2Vault;
        IERC20 d2Asset;
        uint256 d2Holdings;
        uint256 d2Ratio;
        D2Weighting[] d2Weightings;
    }

    address public council;

    Vault[] internal vaults;

    address public cpmAddress;
    ICryptoPunksMarket internal cpm;

    mapping(address => bool) public isIntegrator;
    uint256 public numIntegrators;

    constructor(address _cpmAddress) public {
        cpmAddress = _cpmAddress;
        cpm = ICryptoPunksMarket(cpmAddress);
    }

    // Modifiers -----------------------------------------------//

    modifier onlyIntegrator() {
        require(isIntegrator[_msgSender()], "Not integrator");
        _;
    }

    modifier onlyManager(uint256 vaultId) {
        Vault storage vault = _getVault(vaultId);
        require(_msgSender() == vault.manager, "Not manager");
        _;
    }

    modifier onlyPrivileged(uint256 vaultId, bool includeCouncil) {
        Vault storage vault = _getVault(vaultId);
        if (vault.isFinalized) {
            if (includeCouncil) {
                require(
                    _msgSender() == owner() || _msgSender() == council,
                    "Not owner or council"
                );
            } else {
                require(_msgSender() == owner(), "Not owner");
            }
        } else {
            require(_msgSender() == vault.manager, "Not manager");
        }
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
        Vault storage vault = _getVault(vaultId);
        return
            vault.negateEligibility
                ? !vault.isEligible[nftId]
                : vault.isEligible[nftId];
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
        Vault storage vault = _getVault(vaultId);
        if (vault.supplierBounty.length == 0) {
            return (0, 0);
        }
        uint256 ethBounty = 0;
        uint256 tokenBounty = 0;
        for (uint256 i = 0; i < numTokens; i = i.add(1)) {
            uint256 _vaultSize = isBurn
                ? vaultSize(vaultId).sub(i.add(1))
                : vaultSize(vaultId).add(i);
            (uint256 _ethBounty, uint256 _tokenBounty) = _calcBountyHelper(
                vaultId,
                _vaultSize
            );
            ethBounty = ethBounty.add(_ethBounty);
            tokenBounty = tokenBounty.add(_tokenBounty);
        }
        return (ethBounty, tokenBounty);
    }

    function _calcBountyHelper(uint256 vaultId, uint256 _vaultSize)
        internal
        view
        returns (uint256, uint256)
    {
        BountyParams storage bp = vaults[vaultId].supplierBounty;
        if (_vaultSize >= bp.length) {
            return (0, 0);
        }
        uint256 depth = bp.length.sub(_vaultSize);
        return (
            bp.ethMax.div(bp.length).mul(depth),
            bp.tokenMax.div(bp.length).mul(depth)
        );
    }

    // Management ----------------------------------------------//

    function createVault(
        address _erc20Address,
        address _assetAddress,
        bool _isD2Vault
    ) public whenNotPaused nonReentrant returns (uint256) {
        Vault memory newVault;
        newVault.erc20Address = _erc20Address;
        newVault.assetAddress = _assetAddress;
        newVault.erc20 = IXToken(_erc20Address);
        if (!_isD2Vault) {
            if (_assetAddress != cpmAddress) {
                newVault.nft = IERC721(_assetAddress);
            }
            newVault.negateEligibility = true;
        } else {
            newVault.d2Asset = IERC20(_assetAddress);
            newVault.isD2Vault = true;
        }
        newVault.manager = _msgSender();
        vaults.push(newVault);
        return vaults.length.sub(1);
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
        require(_boolean != isIntegrator[contractAddress], "Already set");
        isIntegrator[contractAddress] = _boolean;
        if (_boolean) {
            numIntegrators = numIntegrators.add(1);
        } else {
            numIntegrators = numIntegrators.sub(1);
        }
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

    function _receiveEthToVault(
        uint256 vaultId,
        uint256 amountRequested,
        uint256 amountSent
    ) internal {
        require(amountSent >= amountRequested, "Value too low");
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = vault.ethBalance.add(amountRequested);
    }

    function _receiveTokenToVault(
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
            if (vault.assetAddress == cpmAddress) {
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
            if (vault.shouldReserve[nftId]) {
                vault.reserves.add(nftId);
            } else {
                vault.holdings.add(nftId);
            }
        }
        emit NFTsDeposited(vaultId, nftIds, _msgSender());
        if (!isDualOp) {
            uint256 amount = nftIds.length * (10**18);
            vault.erc20.mint(_msgSender(), amount);
            emit TokensMinted(vaultId, amount, _msgSender());
        }
    }

    function _mintD2(uint256 vaultId, uint256 amount) internal {
        // TODO:
    }

    function _redeem(uint256 vaultId, uint256 numNFTs, bool isDualOp) internal {
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < numNFTs; i++) {
            uint256[] memory nftIds = new uint256[](1);
            if (vault.holdings.length() > 0) {
                uint256 rand = _getPseudoRand(vault.holdings.length());
                nftIds[0] = vault.holdings.at(rand);
            } else {
                uint256 rand = _getPseudoRand(vault.reserves.length());
                nftIds[i] = vault.reserves.at(rand);
            }
            _redeemHelper(vaultId, nftIds, isDualOp);
        }
    }

    function _redeemD2(uint256 vaultId, uint256 amount) internal {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.burnFrom(
            _msgSender(),
            amount.mul(vault.d2Ratio).div(10**18)
        );
        emit TokensBurned(vaultId, 10**18, _msgSender());
        vault.d2Asset.transfer(_msgSender(), amount);
        vault.d2Holdings = vault.d2Holdings.sub(amount);
    }

    function _redeemHelper(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool isDualOp
    ) internal {
        Vault storage vault = _getVault(vaultId);
        if (!isDualOp) {
            vault.erc20.burnFrom(_msgSender(), nftIds.length * 10**18);
            emit TokensBurned(vaultId, 10**18, _msgSender());
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
            if (vault.assetAddress == cpmAddress) {
                cpm.transferPunk(_msgSender(), nftId);
            } else {
                vault.nft.safeTransferFrom(address(this), _msgSender(), nftId);
            }
        }
        emit NFTsRedeemed(vaultId, nftIds, _msgSender());
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
        _receiveEthToVault(vaultId, ethBounty, msg.value);
        _receiveTokenToVault(vaultId, tokenBounty, _msgSender());
        _redeemHelper(vaultId, nftIds, false);
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
            _receiveEthToVault(vaultId, ethFee.sub(ethBounty), msg.value);
        }
        if (tokenFee > tokenBounty) {
            _receiveTokenToVault(
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

    function redeem(uint256 vaultId, uint256 amount)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        if (!vault.isClosed) {
            (uint256 ethBounty, uint256 tokenBounty) = _calcBounty(
                vaultId,
                amount,
                true
            );
            (uint256 ethFee, uint256 tokenFee) = _calcFee(
                amount,
                vault.burnFees
            );
            if (ethBounty.add(ethFee) > 0) {
                _receiveEthToVault(vaultId, ethBounty.add(ethFee), msg.value);
            }
            if (tokenBounty.add(tokenFee) > 0) {
                _receiveTokenToVault(
                    vaultId,
                    tokenBounty.add(tokenFee),
                    _msgSender()
                );
            }
        }
        if (!vault.isD2Vault) {
            _redeem(vaultId, amount, false);
        } else {
            _redeemD2(vaultId, amount);
        }

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
            _receiveEthToVault(vaultId, ethFee, msg.value);
        }
        if (tokenFee > 0) {
            _receiveTokenToVault(vaultId, tokenFee, _msgSender());
        }
        _mint(vaultId, nftIds, true);
        _redeem(vaultId, nftIds.length, true);
    }

    // onlyPrivileged ------------------------------------------//

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.isEligible[nftIds[i]] = _boolean;
        }
        emit EligibilitySet(vaultId, nftIds, _boolean);
    }

    function setNegateEligibility(uint256 vaultId, bool shouldNegate)
        public
        onlyPrivileged(vaultId, true)
    {
        Vault storage vault = _getVault(vaultId);
        vault.negateEligibility = shouldNegate;
    }

    function setShouldReserve(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i++) {
            vault.shouldReserve[nftIds[i]] = _boolean;
        }
    }

    function setIsReserved(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
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

    function changeTokenName(uint256 vaultId, string memory newName)
        public
        onlyPrivileged(vaultId, true)
    {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.changeName(newName);
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
        onlyPrivileged(vaultId, true)
    {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.changeSymbol(newSymbol);
    }

    // -------------------------------------------------------------//

    function setManager(uint256 vaultId, address newManager)
        public
        onlyManager(vaultId)
    {
        Vault storage vault = _getVault(vaultId);
        vault.manager = newManager;
    }

    function finalizeVault(uint256 vaultId) public onlyManager(vaultId) {
        Vault storage vault = _getVault(vaultId);
        vault.isFinalized = true;
    }

    function closeVault(uint256 vaultId) public onlyPrivileged(vaultId, false) {
        Vault storage vault = _getVault(vaultId);
        vault.isClosed = true;
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        vault.mintFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    uint256 public lastSetBurnFeesSafeCall = 0;

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        vault.burnFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        vault.dualFees = FeeParams(_ethBase, _ethStep, _tokenShare);
    }

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        vault.supplierBounty = BountyParams(ethMax, tokenMax, length);
    }

    function withdrawFromVault(uint256 vaultId, uint256 amount)
        public
        onlyPrivileged(vaultId, false)
    {
        Vault storage vault = _getVault(vaultId);
        if (vault.ethBalance >= amount) {
            _msgSender().transfer(amount);
            vault.ethBalance = vault.ethBalance.sub(amount);
        } else {
            _msgSender().transfer(vault.ethBalance);
            vault.ethBalance = 0;
        }
    }

    function transferTokenOwnership(uint256 vaultId, address to)
        public
        onlyPrivileged(vaultId, false)
    {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.transferOwnership(to);
    }

    function setD2Weightings(
        uint256 vaultId,
        uint256[] memory _vaultIds,
        uint256[] memory _weightings
    ) public onlyPrivileged(vaultId, true) {
        Vault storage vault = _getVault(vaultId);
        require(vault.isD2Vault, "Not D2 vault");
        require(_vaultIds.length == _weightings.length, "Wrong array lengths");
        D2Weighting[] memory _d2Weightings = new D2Weighting[](
            _vaultIds.length
        );
        for (uint256 i = 0; i < _vaultIds.length; i = i.add(1)) {
            D2Weighting memory _d2Weighting = D2Weighting(
                _vaultIds[i],
                _weightings[i]
            );
            _d2Weightings[i] = _d2Weighting;
        }
        vault.d2Weightings = _d2Weightings;
    }

    function setD2Ratio(uint256 vaultId, uint256 newRatio)
        public
        onlyPrivileged(vaultId, true)
    {
        Vault storage vault = _getVault(vaultId);
        require(vault.isD2Vault, "Not D2 vault");
        vault.d2Ratio = newRatio;
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
            if (vault.assetAddress == cpmAddress) {
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

    function setCouncil(address newCouncil) public onlyOwner {
        council = newCouncil;
    }
}
