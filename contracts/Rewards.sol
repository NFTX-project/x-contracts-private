// File: contracts/MasterChef.sol

pragma solidity 0.6.12;


interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to NFTXSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // NFTXSwap must mint EXACTLY the same amount of NFTXSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// MasterChef is the master of NFTX. He can make NFTX and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SUSHI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accNFTXPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accNFTXPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accNFTXPerShare;
    }

    // The SUSHI TOKEN!
    NFTXToken public token;
    // Block number when bonus SUSHI period ends.
    uint256 public bonusEndBlock;
    // SUSHI tokens created per block.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early token makers.
    uint256 public bonusNumber;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    PoolInfo[] public poolInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        NFTXToken _token,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        token = _token;
        tokenPerBlock = _tokenPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        bonusNumber = 3;
    }

    function getBonusPercent() public view returns (uint256) {
      return bonusNumber.mul(100).div(3);
    }

    function setBonusNumber(uint256 newBonusNumber) public onlyOwner {
      require(newBonusNumber > 0 && newBonusNumber < 10, "Invalid bonus");
      bonusNumber = newBonusNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accNFTXPerShare: 0
        }));
    }

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(getBonusPercent()).div(100);
    }

    // View function to see pending SUSHIs on frontend.
    function pendingNFTX(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accNFTXPerShare = pool.accNFTXPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accNFTXPerShare = accNFTXPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accNFTXPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools(uint256 start, uint256 max) public {
        uint256 length = poolInfo.length;
        for (uint256 pid = start; pid < length; pid = pid.add(1)) {
          if (pid > max) {
            return
          }
          updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        token.mint(devaddr, tokenReward.div(10));
        token.mint(address(this), tokenReward);
        pool.accNFTXPerShare = pool.accNFTXPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accNFTXPerShare).div(1e12).sub(user.rewardDebt);
            safeNFTXTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accNFTXPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accNFTXPerShare).div(1e12).sub(user.rewardDebt);
        safeNFTXTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accNFTXPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeNFTXTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.transfer(_to, tokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }
    /////////////////////////////////////////////////////////////////
    // MY ADDIIONS //////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////

    function timeFromDays(uint256 n) public pure returns (uint256) {
      return timeFromHours(n.mul(24))
    }

    function timeFromHours(uint256 n) public pure returns (uint256) {
      return n.mul(60).mul(60);
    }

    uint256 public phase;
    uint256 public phaseStart;

    uint256 public spotlightPool;
    mapping(uint256 => bool) public haveSpotlighted;

    function advance() public onlyOwner {
        uint256 minDuration;
        uint256 maxDuration;
        if (phase == 0) {
          minDuration = timeFromDays(5);
          maxDuration = timeFromDays(10);
        } else {
          minDuration = timeFromHours(30);
          maxDuration = timeFromHours(30);
        }
        require((msg.sender == owner() && now.sub(phaseStart) > minDuration) ||
          now.sub(phaseStart) > maxDuration, "Wait not over");
        uint256 remainingSpotlights = poolInfo.length.sub(3).sub(phase.sub(1));
        uint256 numSteps = _getPseudoRand(remainingSpotlights);

    }

    uint256 public randNonce;

    function _getPseudoRand(uint256 modulus)
        internal
        virtual
        returns (uint256)
    {
        randNonce = randNonce.add(1);
        return
            uint256(
                keccak256(abi.encodePacked(now, msg.sender, randNonce))
            ) %
            modulus;
    }

    function setRandomPool(uint256[] memory _pidSet, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
      uint256 randomIndex = _getPseudoRand(_pidSet.length)
      uint256 pid = _pidSet[randomIndex];
      set(pid, _allocPoint, _withUpdate);
    }

}
