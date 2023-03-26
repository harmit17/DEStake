pragma solidity 0.8.4;

import "https://github.com/UMAprotocol/protocol.git/packages/core/contracts/financial-templates/common-interfaces/IStake.sol";
import "https://github.com/UMAprotocol/protocol.git/packages/core/contracts/financial-templates/common-interfaces/IFinancialProductLibrary.sol";
import "https://github.com/UMAprotocol/protocol.git/packages/core/contracts/financial-templates/expiring-multiparty/ExpiringMultiPartyLib.sol";
import "https://github.com/UMAprotocol/protocol.git/packages/core/contracts/financial-templates/expiring-multiparty/ExpiringMultiPartyCreator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPlatform is Ownable {
    address public collateralToken; // the token used for staking
    uint256 public stakingPeriod; // the length of time for which users can stake
    uint256 public rewardRate; // the rate at which users will be rewarded for staking
    uint256 public totalStaked; // total amount of tokens staked by users
    uint256 public totalRewards; // total amount of rewards paid out to users
    uint256 public constant MAX_REWARD_RATE = 10 ether; // maximum reward rate to prevent abuse
    uint256 public constant MIN_STAKING_PERIOD = 1 days; // minimum staking period to prevent abuse
    uint256 public constant MAX_STAKING_PERIOD = 365 days; // maximum staking period to prevent abuse

    IStake private stakeContract;
    IERC20 private token;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsPaid(address indexed user, uint256 amount);

    constructor(
        address _collateralToken,
        uint256 _stakingPeriod,
        uint256 _rewardRate
    ) {
        require(_collateralToken != address(0), "Invalid token address");
        require(_stakingPeriod >= MIN_STAKING_PERIOD, "Staking period too short");
        require(_stakingPeriod <= MAX_STAKING_PERIOD, "Staking period too long");
        require(_rewardRate > 0 && _rewardRate <= MAX_REWARD_RATE, "Invalid reward rate");

        collateralToken = _collateralToken;
        stakingPeriod = _stakingPeriod;
        rewardRate = _rewardRate;

        token = IERC20(collateralToken);
        stakeContract = IStake(ExpiringMultiPartyCreator.createExpiringMultiParty());
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        uint256 endTime = block.timestamp + stakingPeriod;
        stakeContract.createStake(endTime, msg.sender, amount);

        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake() external {
        uint256 stakedAmount = stakeContract.getStake(msg.sender);
        require(stakedAmount > 0, "No stake found");

        uint256 rewards = calculateRewards(msg.sender);
        totalRewards += rewards;

        stakeContract.endStake(msg.sender);

        require(token.transfer(msg.sender, stakedAmount + rewards), "Transfer failed");

        totalStaked -= stakedAmount;

        emit Unstaked(msg.sender, stakedAmount);
    }

function calculateRewards(address user) public view returns (uint256) {
    uint256 stakedAmount = stakeContract.getStake(user);
    uint256 endTime = stakeContract.getStakeEndTime(user);
    uint256 duration = endTime - block.timestamp;

    uint256 rewards = (stakedAmount * rewardRate * duration) / (stakingPeriod * 1 ether);
    return rewards;
}