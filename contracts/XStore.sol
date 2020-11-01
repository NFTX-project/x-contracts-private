// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IXToken.sol";
import "./IERC721.sol";

contract XStore is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct FeeParams {
        uint256 ethBase;
        uint256 ethStep;
    }

    struct BountyParams {
        uint256 ethMax;
        uint256 length;
    }

    struct Vault {
        address xTokenAddress;
        address nftAddress;
        address manager;
        IXToken xToken;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        EnumerableSet.UintSet reserves;
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
        address d2AssetAddress;
        IERC20 d2Asset;
        uint256 d2Holdings;
    }

    Vault[] internal vaults;

    mapping(address => bool) public isExtension;
    uint256 public numExtensions;
    uint256 public randNonce;
    uint256 public lastSetBurnFeesSafeCall;

    function _getVault(uint256 vaultId)
        internal
        view
        virtual
        returns (Vault storage)
    {
        require(vaultId < vaults.length, "Invalid vaultId");
        return vaults[vaultId];
    }

    function vaultsLength() public view returns (uint256) {
        return vaults.length;
    }

    function xTokenAddressOf(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.xTokenAddress;
    }

    function nftAddressOf(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.nftAddress;
    }

    function managerOf(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.manager;
    }

    function xTokenOf(uint256 vaultId) public view returns (IXToken) {
        Vault storage vault = _getVault(vaultId);
        return vault.xToken;
    }

    function nftOf(uint256 vaultId) public view returns (IERC721) {
        Vault storage vault = _getVault(vaultId);
        return vault.nft;
    }

    function holdingsLengthOf(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.length();
    }

    function holdingsOf(uint256 vaultId, uint256 elem)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.contains(elem);
    }

    function holdingsAtOf(uint256 vaultId, uint256 index)
        public
        view
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.at(index);
    }

    function reservesLengthOf(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.length();
    }

    function reservesContainsOf(uint256 vaultId, uint256 elem)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.contains(elem);
    }

    function reservesAtOf(uint256 vaultId, uint256 index)
        public
        view
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.at(index);
    }

    function isEligibleOf(uint256 vaultId, uint256 id)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.isEligible[id];
    }

    function shouldReserveOf(uint256 vaultId, uint256 id)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.shouldReserve[id];
    }

    function negateEligibilityOf(uint256 vaultId) public view returns (bool) {
        Vault storage vault = _getVault(vaultId);
        return vault.negateEligibility;
    }

    function isFinalizedOf(uint256 vaultId) public view returns (bool) {
        Vault storage vault = _getVault(vaultId);
        return vault.isFinalized;
    }

    function isClosedOf(uint256 vaultId) public view returns (bool) {
        Vault storage vault = _getVault(vaultId);
        return vault.isClosed;
    }

    function mintFeesOf(uint256 vaultId)
        public
        view
        returns (uint256, uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return (vault.mintFees.ethBase, vault.mintFees.ethStep);
    }

    function burnFeesOf(uint256 vaultId)
        public
        view
        returns (uint256, uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return (vault.burnFees.ethBase, vault.burnFees.ethStep);
    }

    function dualFeesOf(uint256 vaultId)
        public
        view
        returns (uint256, uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return (vault.dualFees.ethBase, vault.dualFees.ethStep);
    }

    function supplierBountyOf(uint256 vaultId)
        public
        view
        returns (uint256, uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return (vault.supplierBounty.ethMax, vault.supplierBounty.length);
    }

    function ethBalanceOf(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.ethBalance;
    }

    function tokenBalanceOf(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.tokenBalance;
    }

    function isD2VaultOf(uint256 vaultId) public view returns (bool) {
        Vault storage vault = _getVault(vaultId);
        return vault.isD2Vault;
    }

    function d2AssetAddressOf(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.d2AssetAddress;
    }

    function d2AssetOf(uint256 vaultId) public view returns (IERC20) {
        Vault storage vault = _getVault(vaultId);
        return vault.d2Asset;
    }

    function d2HoldingsOf(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.d2Holdings;
    }

    function setXTokenAddress(uint256 vaultId, address xTokenAddress)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.xTokenAddress = xTokenAddress;
    }

    function setNftAddress(uint256 vaultId, address nftAddress)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.nftAddress = nftAddress;
    }

    function setManager(uint256 vaultId, address manager) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.manager = manager;
    }

    function setXToken(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.xToken = IXToken(vault.xTokenAddress);
    }

    function setNft(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.nft = IERC721(vault.nftAddress);
    }

    function holdingsAdd(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.add(elem);
    }

    function holdingsRemove(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.remove(elem);
    }

    function reservesAdd(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.reserves.add(elem);
    }

    function reservesRemove(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.reserves.remove(elem);
    }

    function setIsEligible(uint256 vaultId, uint256 id, bool _bool)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.isEligible[id] = _bool;
    }

    function setShouldReserve(uint256 vaultId, uint256 id, bool shouldReserve)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.shouldReserve[id] = shouldReserve;
    }

    function setNegateEligibility(uint256 vaultId, bool negateElig)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.negateEligibility = negateElig;
    }

    function setIsFinalized(uint256 vaultId, bool isFinalized)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.isFinalized = isFinalized;
    }

    function setIsClosed(uint256 vaultId, bool isClosed) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.isClosed = isClosed;
    }

    function setMintFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.mintFees = FeeParams(ethBase, ethStep);
    }

    function setBurnFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.burnFees = FeeParams(ethBase, ethStep);
    }

    function setDualFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.dualFees = FeeParams(ethBase, ethStep);
    }

    function setSupplierBounty(uint256 vaultId, uint256 ethMax, uint256 length)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.supplierBounty = BountyParams(ethMax, length);
    }

    function setEthBalance(uint256 vaultId, uint256 ethBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = ethBalance;
    }

    function setTokenBalance(uint256 vaultId, uint256 tokenBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.tokenBalance = tokenBalance;
    }

    function setIsD2Vault(uint256 vaultId, bool isD2Vault) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.isD2Vault = isD2Vault;
    }

    function setD2AssetAddress(uint256 vaultId, address d2AssetAddr)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.d2AssetAddress = d2AssetAddr;
    }

    function setD2Asset(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.d2Asset = IERC20(vault.d2AssetAddress);
    }

    function setD2Holdings(uint256 vaultId, uint256 d2Holdings)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.d2Holdings = d2Holdings;
    }

    ////////////////////////////////////////////////////////////

    function setIsExtension(address addr, bool _isExtension) public onlyOwner {
        isExtension[addr] = _isExtension;
    }

    function setNumExtensions(uint256 _numExtensions) public onlyOwner {
        numExtensions = _numExtensions;
    }

    function setRandNonce(uint256 _randNonce) public onlyOwner {
        randNonce = _randNonce;
    }

    function setLastSetBurnFeesSafeCall(uint256 newNum) public onlyOwner {
        lastSetBurnFeesSafeCall = newNum;
    }

}
