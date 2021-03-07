// // SPDX-License-Identifier: MIT

// pragma solidity 0.6.8;

// import "./NFTXv6.sol";
// import "./IERC20.sol";
// import "./IERC1155.sol";
// import "./IERC1155Receiver.sol";

// contract NFTXv7 is NFTXv6, IERC1155Receiver {

//     mapping(uint256 => bool) public isVault1155;

//     function setIs1155(
//         uint256 vaultId,
//         bool _boolean
//     ) public virtual {
//         onlyPrivileged(vaultId);
//         isVault1155[vaultId] = _boolean;
//     }

//     function _mint(uint256 vaultId, uint256[] memory nftIds, bool isDualOp)
//         internal
//         virtual
//         override
//     {
//         for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
//             uint256 nftId = nftIds[i];
//             require(isEligible(vaultId, nftId), "1");
            
//             if (isVault1155[vaultId]) {
//                 IERC1155 nft = IERC1155(store.nftAddress(vaultId));
//                 nft.safeTransferFrom(msg.sender, address(this), nftId, 1, "");
//             } else {
//                 require(
//                     store.nft(vaultId).ownerOf(nftId) != address(this),
//                     "2"
//                 );
//                 store.nft(vaultId).transferFrom(msg.sender, address(this), nftId);
//                 require(
//                     store.nft(vaultId).ownerOf(nftId) == address(this),
//                     "3"
//                 );
//             }
            
//             store.holdingsAdd(vaultId, nftId);
//         }
//         store.xToken(vaultId).mint(msg.sender, nftIds.length.mul(10**18));
//     }

//     function _redeemHelper(
//         uint256 vaultId,
//         uint256[] memory nftIds,
//         bool isDualOp
//     ) internal virtual override {
//         store.xToken(vaultId).burnFrom(msg.sender, nftIds.length.mul(10**18));
//         for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
//             uint256 nftId = nftIds[i];
//             require(
//                 store.holdingsContains(vaultId, nftId),
//                 "1"
//             );
//             if (store.holdingsContains(vaultId, nftId)) {
//                 store.holdingsRemove(vaultId, nftId);
//             }
//             if (store.flipEligOnRedeem(vaultId)) {
//                 bool isElig = store.isEligible(vaultId, nftId);
//                 store.setIsEligible(vaultId, nftId, !isElig);
//             }
//             if (isVault1155[vaultId]) {
//                 IERC1155 nft = IERC1155(store.nftAddress(vaultId));
//                 nft.safeTransferFrom(address(this), msg.sender, nftId, 1, "");
//             } else {
//                 store.nft(vaultId).safeTransferFrom(
//                     address(this),
//                     msg.sender,
//                     nftId
//                 );
//             }
            
//         }
//     }

//     function requestMint(uint256 vaultId, uint256[] memory nftIds)
//         public
//         payable
//         virtual
//         override
//         nonReentrant
//     {
//         onlyOwnerIfPaused(1);
//         require(store.allowMintRequests(vaultId), "1");
//         // TODO: implement bounty + fees
//         for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
//             require(
//                 store.nft(vaultId).ownerOf(nftIds[i]) != address(this),
//                 "2"
//             );
//             store.nft(vaultId).safeTransferFrom(
//                 msg.sender,
//                 address(this),
//                 nftIds[i]
//             );
//             require(
//                 store.nft(vaultId).ownerOf(nftIds[i]) == address(this),
//                 "3"
//             );
//             store.setRequester(vaultId, nftIds[i], msg.sender);
//         }
//         emit MintRequested(vaultId, nftIds, msg.sender);
//     }

//     function onERC1155Received(
//         address,
//         address,
//         uint256,
//         uint256,
//         bytes memory
//     ) public virtual override returns (bytes4) {
//         return this.onERC1155Received.selector;
//     }

//     function onERC1155BatchReceived(
//         address,
//         address,
//         uint256[] memory,
//         uint256[] memory,
//         bytes memory
//     ) public virtual override returns (bytes4) {
//         return this.onERC1155BatchReceived.selector;
//     }
// }


// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./NFTXv6.sol";
import "./IERC20.sol";
import "./IERC1155Receiver.sol";

contract NFTXv7 is NFTXv6, IERC1155Receiver {

    bool[] public isVault1155;

    function setIs1155(
        uint256 vaultId,
        bool _boolean
    ) public virtual {
        onlyPrivileged(vaultId);
        isVault1155[vaultId] = _boolean;
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds, bool isDualOp)
        internal
        virtual
        override
    {
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            require(isEligible(vaultId, nftId), "Not eligible");
            require(
                store.nft(vaultId).ownerOf(nftId) != address(this),
                "Already owner"
            );
            if (isVault1155[vaultId]) {
                // IERC1155 nft = IERC1155(store.nftAddress(vaultId));
                
                // TODO: transfer IERC1155 to NFTX contract

            } else {
                store.nft(vaultId).transferFrom(msg.sender, address(this), nftId);
            }
            require(
                store.nft(vaultId).ownerOf(nftId) == address(this),
                "Not received"
            );
            store.holdingsAdd(vaultId, nftId);
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
