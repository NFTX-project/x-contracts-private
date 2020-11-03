// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./ITransparentUpgradeableProxy.sol";
import "./ControllerBase.sol";

contract UpgradeController is ControllerBase {
    using SafeMath for uint256;

    address public nftxAddress;
    ITransparentUpgradeableProxy private nftxProxy;
    address public xControllerAddress;
    ITransparentUpgradeableProxy private xControllerProxy;

    constructor(address _nftxAddress, address _xControllerAddress) public {
        ControllerBase.initialize();
        nftxProxy = ITransparentUpgradeableProxy(_nftxAddress);
        xControllerProxy = ITransparentUpgradeableProxy(_xControllerAddress);
    }

    function executeFuncCall(uint256 fcId) public override {
        // TODO: add time check
        if (funcIndex[fcId] == 0) {
            Ownable.transferOwnership(addressParam[fcId]);
        } else if (funcIndex[fcId] == 1) {
            nftxProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 2) {
            nftxProxy.upgradeTo(addressParam[fcId]);
        } else if (funcIndex[fcId] == 3) {
            xControllerProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 4) {
            xControllerProxy.upgradeTo(addressParam[fcId]);
        }
    }

}
