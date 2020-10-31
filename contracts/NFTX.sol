// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";
import "./ERC721Holder.sol";
import "./utils/console.sol";

contract NFTX is Pausable, ReentrancyGuard, ERC721Holder {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    event NFTsDeposited(uint256 vaultId, uint256[] nftIds, address from);
    event NFTsRedeemed(uint256 vaultId, uint256[] nftIds, address to);
    event TokensMinted(uint256 vaultId, uint256 amount, address to);
    event TokensBurned(uint256 vaultId, uint256 amount, address from);
    event DualOp(uint256 vaultId, uint256[] input, address by);
    event DirectRedemption(uint256 vaultId, uint256[] nftIds, address by);
    event VaultCreated(uint256 vaultId, address by);
    event EligibilitySet(
        uint256 vaultId,
        uint256[] nftIds,
        bool _boolean,
        address by
    );
    event NegateEligibilitySet(uint256 vaultId, bool shouldNegate, address by);
    event ReservesIncreased(uint256 vaultId, uint256 nftId);
    event ReservesDecreased(uint256 vaultId, uint256 nftId);
    event EthDeposited(uint256 vaultId, uint256 amount, address by);
    event ExtensionSet(address contractAddress, bool _boolean, address by);
    event EthSentFromVault(uint256 vaultId, uint256 amount, address to);
    event TokenSentFromVault(uint256 vaultId, uint256 amount, address to);
    event EthReceivedByVault(uint256 vaultId, uint256 amount, address from);
    event TokenReceivedByVault(uint256 vaultId, uint256 amount, address from);
    event TokenNameChanged(uint256 vaultId, string newName, address by);
    event TokenSymbolChanged(uint256 vaultId, string newSymbol, address by);
    event ManagerSet(uint256 vaultId, address newManager, address by);
    event VaultFinalized(uint256 vaultId, address by);
    event VaultClosed(uint256 vaultId, address by);
    event MintFeesSet(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        address by
    );
    event BurnFeesSet(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        address by
    );
    event DualFeesSet(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        address by
    );
    event SupplierBountySet(
        uint256 vaultId,
        uint256 ethMax,
        uint256 length,
        address by
    );
    event ShouldReserveSet(
        uint256 vaultId,
        uint256[] nftIds,
        bool _boolean,
        address by
    );
    event IsReservedSet(
        uint256 vaultId,
        uint256[] nftIds,
        bool _boolean,
        address by
    );
    event D2WeightingsSet(
        uint256 vaultId,
        uint256[] _vaultIds,
        uint256[] _weightings,
        address by
    );

    event D2AssetDeposited(uint256 vaultId, uint256 amount, address from);
    event D2AssetRedeemed(uint256 vaultId, uint256 amount, address to);

    struct FeeParams {
        uint256 ethBase;
        uint256 ethStep;
    }

    struct BountyParams {
        uint256 ethMax;
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
        uint256[] d2UnderlyingVaults;
        uint256[] d2UnderlyingWeights;
    }

    Vault[] internal vaults;
    address public cpmAddress;
    ICryptoPunksMarket internal cpm;
    mapping(address => bool) public isExtension;
    uint256 public numExtensions;

    constructor(address _cpmAddress) public {
        cpmAddress = _cpmAddress;
        cpm = ICryptoPunksMarket(cpmAddress);
    }

    modifier onlyExtension() {
        require(isExtension[_msgSender()], "Not extension");
        _;
    }

    modifier onlyManager(uint256 vaultId) {
        Vault storage vault = _getVault(vaultId);
        require(_msgSender() == vault.manager, "Not manager");
        _;
    }

    function onlyPrivileged(uint256 vaultId, bool includeCouncil)
        internal
        view
    {
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
    }

    function numVaults() public view virtual returns (uint256) {
        return vaults.length;
    }

    function isEligible(uint256 vaultId, uint256 nftId)
        public
        view
        virtual
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return
            vault.negateEligibility
                ? !vault.isEligible[nftId]
                : vault.isEligible[nftId];
    }

    function vaultSize(uint256 vaultId) public view virtual returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.isD2Vault 
            ? vault.d2Holdings 
            : vault.holdings.length().add(vault.reserves.length());
    }

    uint256 private randNonce = 0;

    function _getPseudoRand(uint256 modulus)
        internal
        virtual
        returns (uint256)
    {
        randNonce = randNonce.add(1);
        return
            uint256(keccak256(abi.encodePacked(now, msg.sender, randNonce))) %
            modulus;
    }

    function _calcFee(uint256 amount, FeeParams storage feeP, bool isD2)
        internal
        view
        virtual
        returns (uint256)
    {
        if (amount == 0) {
            return 0;
        } else if (isD2) {
            return
                feeP.ethBase.add(
                    feeP.ethStep.mul(amount.sub(10**18)).div(10**18)
                );
        } else {
            uint256 n = amount;
            uint256 nSub1 = amount >= 1 ? n.sub(1) : 0;
            return feeP.ethBase.add(feeP.ethStep.mul(nSub1));
        }
    }

    function _calcBounty(uint256 vaultId, uint256 numTokens, bool isBurn)
        public
        view
        virtual
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        if (vault.supplierBounty.length == 0) {
            return 0;
        }
        uint256 ethBounty = 0;
        for (uint256 i = 0; i < numTokens; i = i.add(1)) {
            uint256 _vaultSize = isBurn
                ? vaultSize(vaultId).sub(i.add(1))
                : vaultSize(vaultId).add(i);
            uint256 _ethBounty = _calcBountyHelper(vaultId, _vaultSize);
            ethBounty = ethBounty.add(_ethBounty);
        }
        return ethBounty;
    }

    function _calcBountyD2(uint256 vaultId, uint256 amount, bool isBurn)
        public
        view
        virtual
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        uint256 length = vault.supplierBounty.length;
        if (length == 0) {
            return 0;
        }
        uint256 prevSize = vaultSize(vaultId);
        uint256 prevDepth = prevSize > length ? 0 : length.sub(prevSize);
        uint256 prevReward = _calcBountyD2Helper(vaultId, prevSize);
        uint256 newSize = isBurn
            ? vaultSize(vaultId).sub(amount)
            : vaultSize(vaultId).add(amount);
        uint256 newDepth = newSize > length ? 0 : length.sub(newSize);
        uint256 newReward = _calcBountyD2Helper(vaultId, newSize);
        uint256 prevTriangle = prevDepth.mul(prevReward).div(2).div(10**18);
        uint256 newTriangle = newDepth.mul(newReward).div(2).div(10**18);

        return
            isBurn
                ? newTriangle.sub(prevTriangle)
                : prevTriangle.sub(newTriangle);
    }

    function _calcBountyD2Helper(uint256 vaultId, uint256 size)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        if (size >= vault.supplierBounty.length) {
            return 0;
        }
        return
            vault.supplierBounty.ethMax.sub(
                vault.supplierBounty.ethMax.mul(size).div(
                    vault.supplierBounty.length
                )
            );
    }

    function _calcBountyHelper(uint256 vaultId, uint256 _vaultSize)
        internal
        view
        virtual
        returns (uint256)
    {
        BountyParams storage bp = vaults[vaultId].supplierBounty;
        if (_vaultSize >= bp.length) {
            return 0;
        }
        uint256 depth = bp.length.sub(_vaultSize);
        return bp.ethMax.div(bp.length).mul(depth);
    }

    function createVault(
        address _erc20Address,
        address _assetAddress,
        bool _isD2Vault
    ) public virtual whenNotPaused nonReentrant returns (uint256) {
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
        uint256 vaultId = vaults.length.sub(1);
        emit VaultCreated(vaultId, _msgSender());
        return vaultId;
    }

    function depositETH(uint256 vaultId) public payable virtual {
        _getVault(vaultId).ethBalance = vaults[vaultId].ethBalance.add(
            msg.value
        );
        emit EthDeposited(vaultId, msg.value, _msgSender());
    }

    function setIsExtension(address contractAddress, bool _boolean)
        public
        virtual
        onlyOwner
    {
        require(_boolean != isExtension[contractAddress], "Already set");
        isExtension[contractAddress] = _boolean;
        if (_boolean) {
            numExtensions = numExtensions.add(1);
        } else {
            numExtensions = numExtensions.sub(1);
        }
        emit ExtensionSet(contractAddress, _boolean, _msgSender());
    }

    function _payEthFromVault(
        uint256 vaultId,
        uint256 amount,
        address payable to
    ) internal virtual {
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
            emit EthSentFromVault(vaultId, amount, to);
        }
    }

    function _receiveEthToVault(
        uint256 vaultId,
        uint256 amountRequested,
        uint256 amountSent
    ) internal virtual {
        require(amountSent >= amountRequested, "Value too low");
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = vault.ethBalance.add(amountRequested);
        emit EthReceivedByVault(vaultId, amountRequested, _msgSender());
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds, bool isDualOp)
        internal
        virtual
    {
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
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
                emit ReservesIncreased(vaultId, nftId);
            } else {
                vault.holdings.add(nftId);
            }
        }
        emit NFTsDeposited(vaultId, nftIds, _msgSender());
        if (!isDualOp) {
            uint256 amount = nftIds.length.mul(10**18);
            vault.erc20.mint(_msgSender(), amount);
            emit TokensMinted(vaultId, amount, _msgSender());
        }
    }

    function _mintD2(uint256 vaultId, uint256 amount) internal virtual {
        Vault storage vault = _getVault(vaultId);
        vault.d2Asset.transferFrom(_msgSender(), address(this), amount);
        emit D2AssetDeposited(vaultId, amount, _msgSender());
        vault.erc20.mint(_msgSender(), amount);
        emit TokensMinted(vaultId, amount, _msgSender());
        vault.d2Holdings = vault.d2Holdings.add(amount);
    }

    function _redeem(uint256 vaultId, uint256 numNFTs, bool isDualOp)
        internal
        virtual
    {
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < numNFTs; i = i.add(1)) {
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

    function _redeemD2(uint256 vaultId, uint256 amount) internal virtual {
        Vault storage vault = _getVault(vaultId);
        vault.erc20.burnFrom(_msgSender(), amount);
        emit TokensBurned(vaultId, amount, _msgSender());
        vault.d2Asset.transfer(_msgSender(), amount);
        emit D2AssetRedeemed(vaultId, amount, _msgSender());
        vault.d2Holdings = vault.d2Holdings.sub(amount);
    }

    function _redeemHelper(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool isDualOp
    ) internal virtual {
        Vault storage vault = _getVault(vaultId);
        if (!isDualOp) {
            vault.erc20.burnFrom(_msgSender(), nftIds.length.mul(10**18));
            emit TokensBurned(vaultId, 10**18, _msgSender());
        }
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
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

    function _getVault(uint256 vaultId)
        internal
        view
        virtual
        returns (Vault storage)
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        return vaults[vaultId];
    }

    function directRedeem(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        virtual
        nonReentrant
        onlyExtension
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        uint256 ethBounty = _calcBounty(vaultId, nftIds.length, true);
        _receiveEthToVault(vaultId, ethBounty, msg.value);
        _redeemHelper(vaultId, nftIds, false);
        emit DirectRedemption(vaultId, nftIds, _msgSender());
    }

    function mint(uint256 vaultId, uint256[] memory nftIds, uint256 d2Amount)
        public
        payable
        virtual
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        uint256 amount = vault.isD2Vault ? d2Amount : nftIds.length;
        uint256 ethBounty = vault.isD2Vault
            ? _calcBountyD2(vaultId, d2Amount, false)
            : _calcBounty(vaultId, amount, false);
        uint256 ethFee = _calcFee(amount, vault.mintFees, vault.isD2Vault);
        if (ethFee > ethBounty) {
            _receiveEthToVault(vaultId, ethFee.sub(ethBounty), msg.value);
        }
        if (vault.isD2Vault) {
            _mintD2(vaultId, d2Amount);

        } else {
            _mint(vaultId, nftIds, false);
        }
        if (ethBounty > ethFee) {
            _payEthFromVault(vaultId, ethBounty.sub(ethFee), _msgSender());

        }
    }

    function redeem(uint256 vaultId, uint256 amount)
        public
        payable
        virtual
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        if (!vault.isClosed) {
            uint256 ethBounty = vault.isD2Vault
                ? _calcBountyD2(vaultId, amount, true)
                : _calcBounty(vaultId, amount, true);
            uint256 ethFee = _calcFee(amount, vault.burnFees, vault.isD2Vault);
            if (ethBounty.add(ethFee) > 0) {
                _receiveEthToVault(vaultId, ethBounty.add(ethFee), msg.value);
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
        virtual
        nonReentrant
        whenNotPaused
    {
        Vault storage vault = _getVault(vaultId);
        require(!vault.isD2Vault, "Is D2 vault");
        require(!vault.isClosed, "Vault is closed");
        uint256 ethFee = _calcFee(
            nftIds.length,
            vault.dualFees,
            vault.isD2Vault
        );
        if (ethFee > 0) {
            _receiveEthToVault(vaultId, ethFee, msg.value);
        }
        _mint(vaultId, nftIds, true);
        _redeem(vaultId, nftIds.length, true);
        emit DualOp(vaultId, nftIds, _msgSender());
    }

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public virtual {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            vault.isEligible[nftIds[i]] = _boolean;
        }
        emit EligibilitySet(vaultId, nftIds, _boolean, _msgSender());
    }

    function setNegateEligibility(uint256 vaultId, bool shouldNegate)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        require(
            vault.holdings.length().add(vault.reserves.length()).add(
                vault.d2Holdings
            ) ==
                0,
            "Vault not empty"
        );
        vault.negateEligibility = shouldNegate;
        emit NegateEligibilitySet(vaultId, shouldNegate, _msgSender());
    }

    function setShouldReserve(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public virtual {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i.add(1)) {
            vault.shouldReserve[nftIds[i]] = _boolean;
        }
        emit ShouldReserveSet(vaultId, nftIds, _boolean, _msgSender());
    }

    function setIsReserved(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public virtual {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        for (uint256 i = 0; i < nftIds.length; i.add(1)) {
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
        emit IsReservedSet(vaultId, nftIds, _boolean, _msgSender());
    }

    function changeTokenName(uint256 vaultId, string memory newName)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.erc20.changeName(newName);
        emit TokenNameChanged(vaultId, newName, _msgSender());
    }

    function changeTokenSymbol(uint256 vaultId, string memory newSymbol)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.erc20.changeSymbol(newSymbol);
        emit TokenSymbolChanged(vaultId, newSymbol, _msgSender());
    }

    function setManager(uint256 vaultId, address newManager)
        public
        virtual
        onlyManager(vaultId)
    {
        Vault storage vault = _getVault(vaultId);
        vault.manager = newManager;
        emit ManagerSet(vaultId, newManager, _msgSender());
    }

    function finalizeVault(uint256 vaultId)
        public
        virtual
        onlyManager(vaultId)
    {
        Vault storage vault = _getVault(vaultId);
        require(!vault.isFinalized, "Already finalized");
        vault.isFinalized = true;
        emit VaultFinalized(vaultId, _msgSender());
    }

    function closeVault(uint256 vaultId) public virtual {
        onlyPrivileged(vaultId, false);
        Vault storage vault = _getVault(vaultId);
        vault.isClosed = true;
        emit VaultClosed(vaultId, _msgSender());
    }

    function setMintFees(uint256 vaultId, uint256 _ethBase, uint256 _ethStep)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.mintFees = FeeParams(_ethBase, _ethStep);
        emit MintFeesSet(vaultId, _ethBase, _ethStep, _msgSender());
    }

    uint256 public lastSetBurnFeesSafeCall = 0;

    function setBurnFees(uint256 vaultId, uint256 _ethBase, uint256 _ethStep)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.burnFees = FeeParams(_ethBase, _ethStep);
        emit BurnFeesSet(vaultId, _ethBase, _ethStep, _msgSender());
    }

    function setDualFees(uint256 vaultId, uint256 _ethBase, uint256 _ethStep)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.dualFees = FeeParams(_ethBase, _ethStep);
        emit DualFeesSet(vaultId, _ethBase, _ethStep, _msgSender());
    }

    function setSupplierBounty(uint256 vaultId, uint256 ethMax, uint256 length)
        public
        virtual
    {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        vault.supplierBounty = BountyParams(ethMax, length);
        emit SupplierBountySet(vaultId, ethMax, length, _msgSender());
    }

    function setD2Weightings(
        uint256 vaultId,
        uint256[] memory _vaultIds,
        uint256[] memory _weightings
    ) public virtual {
        onlyPrivileged(vaultId, true);
        Vault storage vault = _getVault(vaultId);
        require(vault.isD2Vault, "Not D2 vault");
        require(_vaultIds.length == _weightings.length, "Wrong array lengths");
        vault.d2UnderlyingVaults = _vaultIds;
        vault.d2UnderlyingWeights = _weightings;
        emit D2WeightingsSet(vaultId, _vaultIds, _weightings, _msgSender());
    }
}
