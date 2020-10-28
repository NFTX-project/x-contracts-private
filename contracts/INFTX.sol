// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Pausable.sol";
import "./IXToken.sol";
import "./ICryptoPunksMarket.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";

interface INFTX {
    event NFTsDeposited(uint256 vaultId, uint256[] nftIds, address from);
    event NFTsRedeemed(uint256 vaultId, uint256[] nftIds, address to);
    event TokensMinted(uint256 vaultId, uint256 amount, address to);
    event TokensBurned(uint256 vaultId, uint256 amount, address from);

    event EligibilitySet(uint256 vaultId, uint256[] nftIds, bool _boolean);
    event ReservesIncreased(uint256 vaultId, uint256 nftId);
    event ReservesDecreased(uint256 vaultId, uint256 nftId);

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

    function cpmAddress() external view returns (address);

    function xUtilsAddress() external view returns (address);

    function isExtension(address) external view returns (bool);

    function numExtensions() external view returns (uint256);

    function numVaults() external view returns (uint256);

    function isEligible(uint256 vaultId, uint256 nftId)
        external
        view
        returns (bool);

    function vaultSize(uint256 vaultId) external view returns (uint256);

    function createVault(address _erc20Address, address _nftAddress)
        external
        returns (uint256);

    function depositETH(uint256 vaultId) external payable;

    function setIsEligible(
        uint256 vaultId,
        uint256[] calldata nftIds,
        bool _boolean
    ) external;

    function setShouldReserve(
        uint256 vaultId,
        uint256[] calldata nftIds,
        bool _boolean
    ) external;

    function setIsReserved(
        uint256 vaultId,
        uint256[] calldata nftIds,
        bool _boolean
    ) external;

    function setIsExtension(address contractAddress, bool _boolean) external;

    function directRedeem(uint256 vaultId, uint256[] calldata nftIds)
        external
        payable;

    function mint(uint256 vaultId, uint256[] calldata nftIds, uint256 d2Amount)
        external
        payable;

    function redeem(uint256 vaultId, uint256 numNFTs) external payable;

    function mintAndRedeem(uint256 vaultId, uint256[] calldata nftIds)
        external
        payable;

    function changeTokenName(uint256 vaultId, string calldata newName) external;

    function changeTokenSymbol(uint256 vaultId, string calldata newSymbol)
        external;

    function setPaused(bool shouldPause) external;

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) external;

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) external;

    function setDualFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep,
        uint256 _tokenShare
    ) external;

    function setSupplierBounty(
        uint256 vaultId,
        uint256 ethMax,
        uint256 tokenMax,
        uint256 length
    ) external;

    function transferTokenOwnership(uint256 vaultId, address to) external;
}
