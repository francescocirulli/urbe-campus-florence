// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "./CustomERC721.sol";

//0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff AAVE pool address

/**
 * @title Crowdfunding
 * @dev Contract for managing USDC-based crowdfunding campaigns with single contribution policy
 */
contract Crowdfunding {
  /// EVENTS
  event Contribution(address indexed contributor, uint256 amount);
  event FundsClaimed(address indexed admin, uint256 amount);
  event EmergencyWithdraw(address indexed contributor, uint256 amount);
  event Withdraw(address indexed contributor, uint256 amount);

  /// ERRORS
  error CampaignEnded();
  error CampaignNotEnded();
  error NotExistingContribution();
  error InvalidAmount();
  error AlreadyDonated();
  error NotAdmin();
  error GoalNotReached();
  error GoalReached();
  error InvalidAddress();
  error InvalidGoal();
  error InvalidEndTime();
  error invalidAddress();
  /// STATE VARIABLES
  // Money collected by the campaign
  uint256 public collectedFunds;

  // Minimum amount of money to collect
  uint256 public minGoalToCollect;

  // Number of contributors
  uint256 public numberOfContributors;

  // Timestamp of the end of the campaign
  uint256 public endTime;

  // Address of the campaign owner
  address public adminCampaign;

  // Address of the USDC token on the chain
  address public usdcTokenAddress;

  // Token ID for the NFT
  uint256 public tokenId;

  // Custom NFT contract
  CustomNFT public customNFT;

  // AAVE pool
  address public aavePoolAddress;

  //aUSDC token
  address public aUSDC;

  // Mapping to store the contributions of each contributor
  mapping(address => uint256) public contributions;

  /// MODIFIERS
  modifier onlyAdmin() {
    if (msg.sender != adminCampaign) {
      revert NotAdmin();
    }
    _;
  }

  modifier campaignActive() {
    if (block.timestamp > endTime) {
      revert CampaignEnded();
    }
    _;
  }

  modifier campaignEnded() {
    if (block.timestamp < endTime) {
      revert CampaignNotEnded();
    }
    _;
  }

  /// CONSTRUCTOR
  constructor(
    address _adminCampaign,
    uint256 _minGoalToCollect,
    uint256 _endTime,
    address _usdcTokenAddress,
    address _aavePoolAddress,
    address _aUSDC
  ) {
    if (_adminCampaign == address(0)) revert InvalidAddress();
    if (_usdcTokenAddress == address(0)) revert InvalidAddress();
    if (_minGoalToCollect == 0) revert InvalidGoal();
    if (_endTime <= block.timestamp) revert InvalidEndTime();

    adminCampaign = _adminCampaign;
    minGoalToCollect = _minGoalToCollect;
    endTime = _endTime;
    usdcTokenAddress = _usdcTokenAddress;
    aavePoolAddress = _aavePoolAddress;
    aUSDC = _aUSDC;
  }

  /// FUNCTIONS

  function setCustomNFTAddress(address _customNFTAddress) public onlyAdmin {
    if (address(customNFT) != address(0)) {
      revert invalidAddress();
    }
    customNFT = CustomNFT(_customNFTAddress);
  }

  /**
   * @dev Allows users to contribute USDC to the campaign
   * @param amount Amount of USDC to contribute
   * Requirements:
   * - Campaign must not be ended
   * - Amount must be greater than 0
   * - Contributor must not have donated before
   */
  function contribute(uint256 amount) public campaignActive {
    if (amount == 0) {
      revert InvalidAmount();
    }
    if (contributions[msg.sender] > 0) {
      revert AlreadyDonated();
    }

    // Update state before transfer to prevent reentrancy
    contributions[msg.sender] = amount;
    collectedFunds += amount;
    numberOfContributors++;
    tokenId++;
    // Perform the transfer last
    bool success = IERC20(usdcTokenAddress).transferFrom(
      msg.sender,
      address(this),
      amount
    );
    require(success, "USDC transfer failed");

    customNFT.safeMint(msg.sender);

    IERC20(usdcTokenAddress).approve(aavePoolAddress, amount);
    IPool(aavePoolAddress).supply(usdcTokenAddress, amount, address(this), 0); // USDC -> aUSDC    aUSDC -> USDC

    emit Contribution(msg.sender, amount);
  }

  /**
   * @dev Allows contributors to withdraw their funds from an ongoing campaign
   * Requirements:
   * - Campaign must not be ended
   * - Contributor must have an existing contribution
   */
  function withdraw() public campaignActive {
    uint256 amountDonated = contributions[msg.sender];
    if (amountDonated == 0) {
      revert NotExistingContribution();
    }

    // Update state before transfer
    contributions[msg.sender] = 0;
    collectedFunds -= amountDonated;
    numberOfContributors--;

    // Perform the transfer last
    bool success = IERC20(usdcTokenAddress).transfer(msg.sender, amountDonated);
    require(success, "USDC transfer failed");

    emit Withdraw(msg.sender, amountDonated);
  }

  /**
   * @dev Allows admin to claim funds when campaign ends successfully
   * Requirements:
   * - Must be called by admin
   * - Campaign must be ended
   * - Goal must be reached
   */
  function claimFunds() public onlyAdmin campaignEnded {
    if (collectedFunds < minGoalToCollect) {
      revert GoalNotReached();
    }

    uint256 amountToTransfer = IERC20(aUSDC).balanceOf(address(this));

    IERC20(aUSDC).approve(aavePoolAddress, amountToTransfer);
    IPool(aavePoolAddress).withdraw(usdcTokenAddress, amountToTransfer, adminCampaign);

    emit FundsClaimed(adminCampaign, amountToTransfer);
  }

  /**
   * @dev Allows contributors to withdraw if campaign fails
   * Requirements:
   * - Campaign must be ended
   * - Goal must not be reached
   * - Contributor must have an existing contribution
   */
  function emergencyWithdraw() public campaignEnded {
    if (collectedFunds >= minGoalToCollect) {
      revert GoalReached();
    }

    uint256 amountDonated = contributions[msg.sender];
    if (amountDonated == 0) {
      revert NotExistingContribution();
    }

    // Update state before transfer
    contributions[msg.sender] = 0;
    collectedFunds -= amountDonated;
    numberOfContributors--;

    // Perform the transfer last
    bool success = IERC20(usdcTokenAddress).transfer(msg.sender, amountDonated);
    require(success, "USDC transfer failed");

    emit EmergencyWithdraw(msg.sender, amountDonated);
  }
}
