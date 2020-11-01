// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IXToken.sol";
import "./IERC721.sol";
import "./EnumerableSet.sol";

interface IXStore {
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

    function vaultsLength() external view returns (uint256);

    function xTokenAddressOf(uint256 vaultId) external view returns (address);

    function nftAddressOf(uint256 vaultId) external view returns (address);

    function managerOf(uint256 vaultId) external view returns (address);

    function xTokenOf(uint256 vaultId) external view returns (IXToken);

    function nftOf(uint256 vaultId) external view returns (IERC721);

    function holdingsLengthOf(uint256 vaultId) external view returns (uint256);

    function holdingsOf(uint256 vaultId, uint256 elem)
        external
        view
        returns (bool);

    function holdingsAtOf(uint256 vaultId, uint256 index)
        external
        view
        returns (uint256);

    function reservesLengthOf(uint256 vaultId) external view returns (uint256);

    function reservesContainsOf(uint256 vaultId, uint256 elem)
        external
        view
        returns (bool);

    function reservesAtOf(uint256 vaultId, uint256 index)
        external
        view
        returns (uint256);

    function isEligibleOf(uint256 vaultId, uint256 id)
        external
        view
        returns (bool);

    function shouldReserveOf(uint256 vaultId, uint256 id)
        external
        view
        returns (bool);

    function negateEligibilityOf(uint256 vaultId) external view returns (bool);

    function isFinalizedOf(uint256 vaultId) external view returns (bool);

    function isClosedOf(uint256 vaultId) external view returns (bool);

    function mintFeesOf(uint256 vaultId)
        external
        view
        returns (uint256, uint256);

    function burnFeesOf(uint256 vaultId)
        external
        view
        returns (uint256, uint256);

    function dualFeesOf(uint256 vaultId)
        external
        view
        returns (uint256, uint256);

    function supplierBountyOf(uint256 vaultId)
        external
        view
        returns (uint256, uint256);

    function ethBalanceOf(uint256 vaultId) external view returns (uint256);

    function tokenBalanceOf(uint256 vaultId) external view returns (uint256);

    function isD2VaultOf(uint256 vaultId) external view returns (bool);

    function d2AssetAddressOf(uint256 vaultId) external view returns (address);

    function d2AssetOf(uint256 vaultId) external view returns (IERC20);

    function d2HoldingsOf(uint256 vaultId) external view returns (uint256);

    function setXTokenAddress(uint256 vaultId, address xTokenAddress) external;

    function setNftAddress(uint256 vaultId, address nftAddress) external;

    function setManager(uint256 vaultId, address manager) external;

    function setXToken(uint256 vaultId) external;

    function setNft(uint256 vaultId) external;

    function holdingsAdd(uint256 vaultId, uint256 elem) external;

    function holdingsRemove(uint256 vaultId, uint256 elem) external;

    function reservesAdd(uint256 vaultId, uint256 elem) external;

    function reservesRemove(uint256 vaultId, uint256 elem) external;

    function setIsEligible(uint256 vaultId, uint256 id, bool _bool) external;

    function setShouldReserve(uint256 vaultId, uint256 id, bool shouldReserve)
        external;

    function setNegateEligibility(uint256 vaultId, bool negateElig) external;

    function setIsFinalized(uint256 vaultId, bool isFinalized) external;

    function setIsClosed(uint256 vaultId, bool isClosed) external;

    function setMintFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        external;

    function setBurnFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        external;

    function setDualFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        external;

    function setSupplierBounty(uint256 vaultId, uint256 ethMax, uint256 length)
        external;

    function setEthBalance(uint256 vaultId, uint256 ethBalance) external;

    function setTokenBalance(uint256 vaultId, uint256 tokenBalance) external;

    function setIsD2Vault(uint256 vaultId, bool isD2Vault) external;

    function setD2AssetAddress(uint256 vaultId, address d2AssetAddr) external;

    function setD2Asset(uint256 vaultId) external;

    function setD2Holdings(uint256 vaultId, uint256 d2Holdings) external;

    function setIsExtension(address addr, bool _isExtension) external;

    function setNumExtensions(uint256 _numExtensions) external;

    function setRandNonce(uint256 _randNonce) external;

    function setLastSetBurnFeesSafeCall(uint256 newNum) external;

}
