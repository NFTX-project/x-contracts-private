// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

interface IProfitable {
    enum FeeType {Mint, Burn, Dual}
    event MintFeesSet(uint256[] mintFees);
    event BurnFeesSet(uint256[] burnFees);
    event DualFeesSet(uint256[] dualFees);
    event SupplierBountySet(uint256[] supplierBounty);
    event IntegratorSet(address account, bool isVerified);

    function getFeesArray(FeeType feeType)
        external
        view
        returns (uint256[] memory);

    function setFeesArray(FeeType feeType, uint256[] calldata newFees) external;

    function setSupplierBounty(uint256[] calldata newSupplierBounty) external;

    function isIntegrator(address account) external view returns (bool);

    function getNumIntegrators() external view returns (uint256);

    function setIntegrator(address account, bool isVerified) external;

    function getFee(address account, uint256 numTokens, FeeType feeType)
        external
        view
        returns (uint256);

    function getBurnBounty(uint256 numTokens, uint256 reservesLength)
        external
        view
        returns (uint256);

    function getMintBounty(uint256 numTokens, uint256 reservesLength)
        external
        view
        returns (uint256);
    function transferOwnership(address newOwner) external;
}
