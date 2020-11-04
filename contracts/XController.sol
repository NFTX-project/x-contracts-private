// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ControllerBase.sol";
import "./INFTX.sol";
import "./IXStore.sol";
import "./Initializable.sol";

contract XController is ControllerBase {
    INFTX private nftx;
    IXStore store;

    ITransparentUpgradeableProxy private nftxProxy;
    ITransparentUpgradeableProxy private controllerProxy;

    /* uint256 numFuncCalls;

    mapping(uint256 => uint256) public time;
    mapping(uint256 => uint256) public funcIndex;
    mapping(uint256 => address payable) public addressParam; */
    mapping(uint256 => uint256) public uintParam;
    mapping(uint256 => string) public stringParam;
    mapping(uint256 => uint256[]) public uintArrayParam;
    mapping(uint256 => bool) public boolParam;

    mapping(uint256 => uint256) public vaultIdToPendingEligAdditions;

    function executeFuncCall(uint256 fcId) public override {
        if (funcIndex[fcId] == 0) {
            onlyIfPastDelay(1, time[fcId]);
            Ownable.transferOwnership(addressParam[fcId]);
        } else if (funcIndex[fcId] == 1) {
            onlyIfPastDelay(2, time[fcId]);
            nftx.transferOwnership(addressParam[fcId]);
        } else if (funcIndex[fcId] == 2) {
            // TODO: check magnitude of change
            //       - keep track of pending elig additions
            //       - less than 10% pending change is (1)
            //       - less than 1% pending change is (0)
            onlyIfPastDelay(2, time[fcId]);
            nftx.setIsEligible(
                uintParam[fcId],
                uintArrayParam[fcId],
                boolParam[fcId]
            );
        } else if (funcIndex[fcId] == 3) {
            onlyIfPastDelay(0, time[fcId]); // vault must be empty
            nftx.setNegateEligibility(funcIndex[fcId], boolParam[fcId]);
        } else if (funcIndex[fcId] == 4) {
            onlyIfPastDelay(0, time[fcId]);
            nftx.setShouldReserve(
                uintParam[fcId],
                uintArrayParam[fcId],
                boolParam[fcId]
            );
        } else if (funcIndex[fcId] == 5) {
            onlyIfPastDelay(0, time[fcId]);
            nftx.setIsReserved(
                uintParam[fcId],
                uintArrayParam[fcId],
                boolParam[fcId]
            );
        } else if (funcIndex[fcId] == 6) {
            onlyIfPastDelay(1, time[fcId]);
            nftx.changeTokenName(uintParam[fcId], stringParam[fcId]);
        } else if (funcIndex[fcId] == 7) {
            onlyIfPastDelay(1, time[fcId]);
            nftx.changeTokenSymbol(uintParam[fcId], stringParam[fcId]);
        } else if (funcIndex[fcId] == 8) {
            onlyIfPastDelay(0, time[fcId]);
            nftx.closeVault(uintParam[fcId]);
        } else if (funcIndex[fcId] == 9) {
            onlyIfPastDelay(0, time[fcId]);
            nftx.setMintFees(
                uintArrayParam[fcId][0],
                uintArrayParam[fcId][1],
                uintArrayParam[fcId][2]
            );
        } else if (funcIndex[fcId] == 10) {
            // TODO: check magnitude of change
            onlyIfPastDelay(2, time[fcId]);
            nftx.setBurnFees(
                uintArrayParam[fcId][0],
                uintArrayParam[fcId][1],
                uintArrayParam[fcId][2]
            );
        } else if (funcIndex[fcId] == 11) {
            onlyIfPastDelay(0, time[fcId]);
            nftx.setDualFees(
                uintArrayParam[fcId][0],
                uintArrayParam[fcId][1],
                uintArrayParam[fcId][2]
            );
        } else if (funcIndex[fcId] == 12) {
            // TODO: check magnitude of change
            onlyIfPastDelay(2, time[fcId]);
            nftx.setSupplierBounty(
                uintArrayParam[fcId][0],
                uintArrayParam[fcId][1],
                uintArrayParam[fcId][2]
            );
        }
    }

    function initXController(address nftxAddress) public initializer {
        initOwnable();
        nftx = INFTX(nftxAddress);
    }

    function stageFuncCall(
        uint256 _funcIndex,
        address payable _addressParam,
        uint256 _uintParam,
        string memory _stringParam,
        uint256[] memory _uintArrayParam,
        bool _boolParam
    ) public onlyOwner {
        uint256 fcId = numFuncCalls;
        numFuncCalls = numFuncCalls.add(1);
        time[fcId] = now;
        funcIndex[fcId] = _funcIndex;
        addressParam[fcId] = _addressParam;
        uintParam[fcId] = _uintParam;
        stringParam[fcId] = _stringParam;
        uintArrayParam[fcId] = _uintArrayParam;
        boolParam[fcId] = _boolParam;
    }

}
