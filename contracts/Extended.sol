// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./XVaultSafe.sol";

import "./IEligible.sol";
import "./IRandomizable.sol";
import "./IControllable.sol";
import "./IProfitable.sol";

contract Extended is XVaultSafe {
    event DirectRedemption(uint256 xId, address by, address indexed to);

    IEligible internal eligibleContract;
    IRandomizable internal randomizableContract;
    IControllable internal controllableContract;
    IProfitable internal profitableContract;

    function setExtensions(
        address eligibleAddress,
        address randomizableAddress,
        address controllableAddress,
        address profitableAddress
    ) internal {
        eligibleContract = IEligible(eligibleAddress);
        randomizableContract = IRandomizable(randomizableAddress);
        controllableContract = IControllable(controllableAddress);
        profitableContract = IProfitable(profitableAddress);
    }

    modifier onlyController() {
        require(
            controllableContract.isController(_msgSender()),
            "Not a controller"
        );
        _;
    }

    function directRedeem(uint256 tokenId, address to) public onlyController {
        require(getERC20().balanceOf(to) >= 10**18, "ERC20 balance too small");
        bool toSelf = (to == address(this));
        require(
            toSelf || (getERC20().allowance(to, address(this)) >= 10**18),
            "ERC20 allowance too small"
        );
        require(getReserves().contains(tokenId), "Not in holdings");
        getERC20().burnFrom(to, 10**18);
        getReserves().remove(tokenId);
        if (!toSelf) {
            getCPM().transferX(to, tokenId);
        }
        emit DirectRedemption(tokenId, _msgSender(), to);
    }

}
