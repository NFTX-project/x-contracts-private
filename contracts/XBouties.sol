// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./TokenAppController.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";

contract XBounties is TokenAppController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => uint256) public price;
    mapping(address => uint256) public maxQuantity;
    mapping(address => uint256) public totalReceived;

    address public daoMultiSig;
    uint256 vestedUntil;

    constructor(address _tokenManager, address _daoMultiSig, uint256 _vestedUntil ) public {
        initTAC();
        setTokenManager(_tokenManager);
        vestUntil = _vestedUntil;
    }

    function fillBounty(address _fundToken, uint256 fundAmount) public {
        uint256 requestedAmount = fundAmount.mul(price[_fundToken]);
        uint256 remainingAmount = maxQuantity[_fundToken]
            .sub(totalReceived[_fundToken])
            .mul(price[_fundToken]);
        uint256 willGive = remainingAmount < requestedAmount
            ? remainingAmount
            : fundAmount;
        uint256 willTake = fundAmount.mul(willGive).div(requestedAmount);
        require(willTake > 0, "Nothing to take");
        IERC20 fundToken = IERC20(_fundToken);
        fundToken.safeTransferFrom(msg.sender, daoMultiSig, willTake);
        callAssignVested(msg.sender, willGive,)
    }
}
