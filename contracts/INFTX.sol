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

    function setExtension(address contractAddress, bool _boolean) external;

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
