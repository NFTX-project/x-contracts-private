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

    function executeFuncCall(uint256 fcId) public override onlyOwner {
        super.executeFuncCall(fcId);
        if (funcIndex[fcId] == 3) {
            nftxProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 4) {
            nftxProxy.upgradeTo(addressParam[fcId]);
        } else if (funcIndex[fcId] == 5) {
            xControllerProxy.changeAdmin(addressParam[fcId]);
        } else if (funcIndex[fcId] == 6) {
            xControllerProxy.upgradeTo(addressParam[fcId]);
        }
    }

}
