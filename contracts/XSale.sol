// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./SafeMath.sol";
import "./Pausable.sol";
import "./INFTX.sol";
import "./IXStore.sol";
import "./IERC721.sol";
import "./ITokenManager.sol";
import "./Context.sol";
import "./ReentrancyGuard.sol";

contract XSale is Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    address public nftxAddress;
    address public nftxTokenAddress;

    INFTX public nftx;
    IXStore public xStore;
    IERC20 public nftxToken;
    ITokenManager public tokenManager;

    uint64 public constant vestedUntil = 1610250000;

    mapping(uint256 => Bounty[]) public bounties;

    struct Bounty {
        uint256 reward;
        uint256 request;
    }

    constructor(
        address _nftxAddress,
        address _nftxTokenAddress,
        address tokenManagerAddress
    ) public {
        initOwnable();
        nftxAddress = _nftxAddress;
        nftxTokenAddress = _nftxTokenAddress;
        nftx = INFTX(nftxAddress);
        xStore = IXStore(nftx.storeAddress());
        nftxToken = IERC20(nftxTokenAddress);
        tokenManager = ITokenManager(tokenManagerAddress);
    }

    function addBounty(uint256 vaultId, uint256 reward, uint256 request)
        public
        onlyOwner
    {
        Bounty memory newBounty;
        newBounty.reward = reward;
        newBounty.request = request;
        bounties[vaultId].push(newBounty);
    }

    function setBounty(
        uint256 vaultId,
        uint256 bountyIndex,
        uint256 newReward,
        uint256 newRequest
    ) public onlyOwner {
        Bounty storage bounty = bounties[vaultId][bountyIndex];
        bounty.reward = newReward;
        bounty.request = newRequest;
    }

    function fillBounty(uint256 vaultId, uint256 bountyIndex, uint256 amount)
        public
        nonReentrant
    {
        Bounty storage bounty = bounties[vaultId][bountyIndex];
        uint256 _amount = bounty.request < amount ? bounty.request : amount;
        if (_amount > 0) {
            xStore.xToken(vaultId).transferFrom(
                _msgSender(),
                nftxAddress,
                _amount
            );
            uint256 _reward = bounty.reward.mul(_amount).div(bounty.request);
            bounty.request = bounty.request.sub(_amount);
            bounty.reward = bounty.reward.sub(_reward);
            tokenManager.assignVested(
                _msgSender(),
                _reward,
                vestedUntil,
                vestedUntil,
                vestedUntil,
                false
            );
        }
    }
}
