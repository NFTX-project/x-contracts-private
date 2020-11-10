// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./INFTX.sol";
import "./IXStore.sol";
import "./IERC721.sol";
import "./Context.sol";

contract XSale is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    // bool public isPaused;

    address public nftxAddress;
    address public nftxTokenAddress;

    INFTX public nftx;
    IXStore public xStore;
    IERC20 public nftxToken;

    mapping(uint256 => NftBounty) public nftReqs;

    mapping(uint256 => NftBounty[]) public nftBounties;

    struct NftBounty {
        uint256 priceInNftx;
        uint256 quantity;
    }

    constructor(address _nftxAddress, address _nftxTokenAddress) public {
        nftxAddress = _nftxAddress;
        nftxTokenAddress = _nftxTokenAddress;
        nftx = INFTX(nftxAddress);
        xStore = IXStore(nftx.storeAddress());
        nftxToken = IERC20(nftxTokenAddress);
    }

    // function setIsPaused(bool _isPaused) public onlyOwner {
    //     isPaused = _isPaused;
    // }

    function _addBounty(uint256 vaultId, uint256 nftxPrice, uint256 quantity)
        internal
    {
        NftBounty memory newNftBounty;
        newNftBounty.priceInNftx = nftxPrice;
        newNftBounty.quantity = quantity;
        nftBounties[vaultId].push(newNftBounty);
    }

    function _setBounty(
        uint256 vaultId,
        uint256 bountyIndex,
        uint256 nftxPrice,
        uint256 quantity
    ) internal {
        NftBounty storage nftBounty = nftBounties[vaultId][bountyIndex];
        nftBounty.priceInNftx = nftxPrice;
        nftBounty.quantity = quantity;
    }

    function fillBounty(
        uint256 vaultId,
        uint256 bountyIndex,
        uint256[] memory nftIds
    ) public {
        uint256 acc;
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            if (
                !nftx.isEligible(vaultId, nftIds[i]) ||
                nftBounties[vaultId][bountyIndex].quantity < 1
            ) {
                break;
            }
            xStore.nft(vaultId).safeTransferFrom(
                _msgSender(),
                nftxAddress,
                nftIds[i]
            );
            nftBounties[vaultId][bountyIndex]
                .quantity = nftBounties[vaultId][bountyIndex].quantity.sub(1);
            acc = acc.add(nftBounties[vaultId][bountyIndex].priceInNftx);
        }
        // TODO: transfer vested NFTX tokens
    }
}
