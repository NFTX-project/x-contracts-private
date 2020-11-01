// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./ReentrancyGuard.sol";
import "./ERC721Holder.sol";
import "./IXStore.sol";
import "./utils/console.sol";

contract NFTX is Pausable, ReentrancyGuard, ERC721Holder {
    using SafeMath for uint256;

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

    address public cpmAddress;
    ICryptoPunksMarket internal cpm;

    address public storeAddress;
    IXStore internal store;

    function initialize(address _cpmAddress, address _storeAddress)
        public
        onlyOwner
    {
        require(cpmAddress == address(0), "CPM already set");
        cpmAddress = _cpmAddress;
        cpm = ICryptoPunksMarket(cpmAddress);
        storeAddress = _storeAddress;
        store = IXStore(storeAddress);
    }

    modifier onlyExtension() {
        require(store.isExtension[_msgSender()], "Not extension");
        _;
    }

    modifier onlyManager(uint256 vaultId) {
        require(_msgSender() == store.managerOf(vaultId), "Not manager");
        _;
    }

    function onlyPrivileged(uint256 vaultId, bool includeCouncil)
        internal
        view
    {
        if (store.isFinalizedOf(vaultId)) {
            if (includeCouncil) {
                require(
                    _msgSender() == owner() || _msgSender() == council,
                    "Not owner or council"
                );
            } else {
                require(_msgSender() == owner(), "Not owner");
            }
        } else {
            require(_msgSender() == store.managerOf(vaultId), "Not manager");
        }
    }

    function numVaults() public view virtual returns (uint256) {
        return store.vaultsLength();
    }

    function isEligible(uint256 vaultId, uint256 nftId)
        public
        view
        virtual
        returns (bool)
    {
        return
            store.negateEligibilityOf(vaultId)
                ? !store.isEligibleOf(vaultId, nftId)
                : store.isEligibleOf(vaultId, nftId);
    }

    function vaultSize(uint256 vaultId) public view virtual returns (uint256) {
        return
            store.isD2VaultOf(vaultId)
                ? store.d2HoldingsOf(vaultId)
                : store.holdingsLengthOf(vaultId).add(
                    store.reservesLengthOf(vaultId)
                );
    }

    function _getPseudoRand(uint256 modulus)
        internal
        virtual
        returns (uint256)
    {
        store.setRandNonce(store.randNonce().add(1));
        return
            uint256(
                keccak256(abi.encodePacked(now, msg.sender, store.randNonce()))
            ) %
            modulus;
    }

    function _calcFee(
        uint256 amount,
        uint256 ethBase,
        uint256 ethStep,
        bool isD2
    ) internal view virtual returns (uint256) {
        if (amount == 0) {
            return 0;
        } else if (isD2) {
            return ethBase.add(ethStep.mul(amount.sub(10**18)).div(10**18));
        } else {
            uint256 n = amount;
            uint256 nSub1 = amount >= 1 ? n.sub(1) : 0;
            return ethBase.add(ethStep.mul(nSub1));
        }
    }

    function _calcBounty(uint256 vaultId, uint256 numTokens, bool isBurn)
        public
        view
        virtual
        returns (uint256)
    {
        (uint256 ethMax, uint256 length) = store.supplierBountyOf(vaultId);
        if (length == 0) {
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
        (uint256 ethMax, uint256 length) = store.supplierBounty(vaultId);
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
        if (size >= store.supplierBounty(vaultId).length) {
            return 0;
        }
        (uint256 ethMax, uint256 length) = store.supplierBounty(vaultId);
        return ethMax.sub(ethMax.mul(size).div(length));
    }

    function _calcBountyHelper(uint256 vaultId, uint256 _vaultSize)
        internal
        view
        virtual
        returns (uint256)
    {
        (uint256 ethMax, uint256 length) = store.supplierBounty(vaultId);
        if (_vaultSize >= length) {
            return 0;
        }
        uint256 depth = length.sub(_vaultSize);
        return ethMax.div(length).mul(depth);
    }

    function createVault(
        address _xTokenAddress,
        address _assetAddress,
        bool _isD2Vault
    ) public virtual whenNotPaused nonReentrant returns (uint256) {
        uint256 vaultId = store.addNewVault();
        store.setXTokenAddress(vaultId, _xTokenAddress);
        store.setAssetAddress(vaultId, _assetAddress);
        store.setXToken(vaultId);
        if (!_isD2Vault) {
            if (_assetAddress != cpmAddress) {
                store.setNft(vaultId);
            }
            store.setNegateEligibility(true);
        } else {
            store.setD2Asset(vaultId);
            store.setIsD2Vault(vaultId, true);
        }
        store.setManager(_msgSender());
        emit VaultCreated(vaultId, _msgSender());
        return vaultId;
    }

    function depositETH(uint256 vaultId) public payable virtual {
        store.setEthBalance(
            vaultId,
            store.ethBalance(vaultId).add(msg.value)
        );
        emit EthDeposited(vaultId, msg.value, _msgSender());
    }

    function setExtension(address contractAddress, bool _boolean)
        public
        virtual
        onlyOwner
    {
        require(_boolean !=  store.isExtension(contractAddress), "Already set");
        store.setIsExtension(contractAddress, _boolean);
    }

    function _payEthFromVault(
        uint256 vaultId,
        uint256 amount,
        address payable to
    ) internal virtual {
        uint256 ethBalance = store.ethBalance(vaultId);
        uint256 amountToSend = ethBalance < amount ? ethBalance : amount;
        if (amountToSend > 0) {
            store.setEthBalance(vaultId, ethBalance.sub(amountToSend));
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
        store.setEthBalance(vaultId, store.ethBalance(vaultId).add(amountRequested));
        emit EthReceivedByVault(vaultId, amountRequested, _msgSender());
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds, bool isDualOp)
        internal
        virtual
    {
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            require(isEligible(vaultId, nftId), "Not eligible");
            if (store.assetAddress(vaultId) == cpmAddress) {
                cpm.buyPunk(nftId);
            } else {
                IERC721 memory nft = store.nft(vaultId);
                require(
                    nft.ownerOf(nftId) != address(this),
                    "Already owner"
                );
                nft.safeTransferFrom(_msgSender(), address(this), nftId);
                require(
                    nft.ownerOf(nftId) == address(this),
                    "Not received"
                );
            }
            if (store.shouldReserve(vaultId, nftId)) {
                store.reservesAdd(vaultId, nftId);
                emit ReservesIncreased(vaultId, nftId);
            } else {
                store.holdingsAdd(vaultId, nftId);
            }
        }
        emit NFTsDeposited(vaultId, nftIds, _msgSender());
        if (!isDualOp) {
            uint256 amount = nftIds.length.mul(10**18);
            store.xToken(vaultId).mint(_msgSender(), amount);
            emit TokensMinted(vaultId, amount, _msgSender());
        }
    }

    function _mintD2(uint256 vaultId, uint256 amount) internal virtual {
        store.d2Asset(vaultId).transferFrom(_msgSender(), address(this), amount);
        emit D2AssetDeposited(vaultId, amount, _msgSender());
        store.xToken(vaultId).mint(_msgSender(), amount);
        emit TokensMinted(vaultId, amount, _msgSender());
        store.setD2Holdings(vaultId, store.d2Holdings(vaultId).add(amount));
    }

    function _redeem(uint256 vaultId, uint256 numNFTs, bool isDualOp)
        internal
        virtual
    {
        for (uint256 i = 0; i < numNFTs; i = i.add(1)) {
            uint256[] memory nftIds = new uint256[](1);
            if (store.holdingsLength(vaultId) > 0) {
                uint256 rand = _getPseudoRand(store.holdingsLength(vaultId));
                nftIds[0] = store.holdingsAt(vaultId, rand);
            } else {
                uint256 rand = _getPseudoRand(store.reservesLength());
                nftIds[i] = store.reservesAt(vaultId, rand);
            }
            _redeemHelper(vaultId, nftIds, isDualOp);
        }
    }

    function _redeemD2(uint256 vaultId, uint256 amount) internal virtual {
        store.xToken(vaultId).burnFrom(_msgSender(), amount);
        emit TokensBurned(vaultId, amount, _msgSender());
        store.d2Asset(vaultId).transfer(_msgSender(), amount);
        emit D2AssetRedeemed(vaultId, amount, _msgSender());
        store.setD2Holdings(vaultId, store.d2Holdings(vaultId).sub(amount));
    }

    function _redeemHelper(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool isDualOp
    ) internal virtual {
        if (!isDualOp) {
            store.xToken(vaultId).burnFrom(_msgSender(), nftIds.length.mul(10**18));
            emit TokensBurned(vaultId, 10**18, _msgSender());
        }
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            require(
                store.holdingsContains(vaultId, nftId) ||
                    store.reservesContains(vaultId, nftId),
                "NFT not in vault"
            );
            if (store.holdingsContains(vaultId, nftId)) {
                store.holdingsRemove(vaultId, nftId);
            } else {
                store.reservesRemove(vaultId, nftId);
                emit ReservesDecreased(vaultId, nftId);
            }
            if (store.assetAddress(vaultId) == cpmAddress) {
                cpm.transferPunk(_msgSender(), nftId);
            } else {
                store.nft(vaultId).safeTransferFrom(address(this), _msgSender(), nftId);
            }
        }
        emit NFTsRedeemed(vaultId, nftIds, _msgSender());
    }

    function directRedeem(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
        virtual
        nonReentrant
        onlyExtension
    {
        require(vaultId < store.vaultsLength, "Invalid vaultId");
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
        uint256 amount = store.isD2Vault(vaultId) ? d2Amount : nftIds.length;
        uint256 ethBounty = store.isD2Vault(vaultId)
            ? _calcBountyD2(vaultId, d2Amount, false)
            : _calcBounty(vaultId, amount, false);
        (uint256 ethBase, uint256 ethStep) = store.mintFees(vaultId);
        uint256 ethFee = _calcFee(amount, ethBase, ethStep, store.isD2Vault(vaultId));
        if (ethFee > ethBounty) {
            _receiveEthToVault(vaultId, ethFee.sub(ethBounty), msg.value);
        }
        if (store.isD2Vault(vaultId)) {
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
        if (!store.isClosed(vaultId)) {
            uint256 ethBounty = store.isD2Vault(vaultId)
                ? _calcBountyD2(vaultId, amount, true)
                : _calcBounty(vaultId, amount, true);
            (uint256 ethBase, uint256 ethStep) = store.burnFees(vaultId);
            uint256 ethFee = _calcFee(
                amount, 
                ethBase, 
                ethStep, 
                store.isD2Vault(vaultId)
            );
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
