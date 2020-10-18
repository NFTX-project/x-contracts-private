// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

interface IXVault {
    event TokenBurnedSafely(uint256 xId, address indexed to);

    event TokenMinted(uint256 tokenId, address indexed to);
    event TokensMinted(uint256[] tokenIds, address indexed to);
    event TokenBurned(uint256 tokenId, address indexed to);
    event TokensBurned(uint256[] tokenIds, address indexed to);

    function mintX(uint256 tokenId) external payable;
    function mintXMultiple(uint256[] calldata tokenIds) external payable;

    function getMintBounty(uint256 numTokens) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function mintRetroactively(uint256 tokenId, address to) external;

    function redeemRetroactively(address to) external;

    function migrate(address to, uint256 max) external;

    function changeTokenName(string calldata newName) external;

    function changeTokenSymbol(string calldata newSymbol) external;

    function setReverseLink() external;

    function withdraw(address payable to) external;

    function pause() external;

    function unpause() external;
}
