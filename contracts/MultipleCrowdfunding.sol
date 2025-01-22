// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Multi-Campaign Crowdfunding
 * @dev Contract for managing multiple USDC-based crowdfunding campaigns
 * @notice Allows creation and management of multiple concurrent crowdfunding campaigns
 */
contract Crowdfunding {
    /// EVENTS
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed admin,
        uint256 goal,
        uint256 endTime
    );
    event Contribution(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    event FundsClaimed(
        uint256 indexed campaignId,
        address indexed admin,
        uint256 amount
    );
    event EmergencyWithdraw(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    event Withdraw(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    /// ERRORS
    error CampaignEnded();
    error CampaignNotEnded();
    error NotExistingContribution();
    error InvalidAmount();
    error AlreadyDonated();
    error NotAdmin();
    error GoalNotReached();
    error GoalReached();
    error CampaignNotFound();
    error InvalidEndTime();
    error InvalidGoal();
    error InvalidAddress();

    /// STRUCTS
    struct Campaign {
        address adminCampaign;
        uint256 minGoalToCollect;
        uint256 endTime;
        uint256 collectedFunds;
        uint256 numberOfContributors;
    }

    /// STATE VARIABLES
    address public usdcTokenAddress;
    uint256 public campaignCounter;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    /// MODIFIERS
    modifier validCampaign(uint256 campaignId) {
        if (campaigns[campaignId].adminCampaign == address(0)) revert CampaignNotFound();
        _;
    }

    modifier onlyAdmin(uint256 campaignId) {
        if (msg.sender != campaigns[campaignId].adminCampaign) revert NotAdmin();
        _;
    }

    modifier campaignActive(uint256 campaignId) {
        if (block.timestamp > campaigns[campaignId].endTime) revert CampaignEnded();
        _;
    }

    modifier campaignEnded(uint256 campaignId) {
        if (block.timestamp < campaigns[campaignId].endTime) revert CampaignNotEnded();
        _;
    }

    /// CONSTRUCTOR
    constructor(address _usdcTokenAddress) {
        if (_usdcTokenAddress == address(0)) revert InvalidAddress();
        usdcTokenAddress = _usdcTokenAddress;
    }

    /// FUNCTIONS

    /**
     * @dev Creates a new crowdfunding campaign
     * @param _minGoalToCollect Minimum amount of USDC to be raised
     * @param _endTime Timestamp when the campaign ends
     * @return campaignId Unique identifier of the created campaign
     */
    function createCampaign(
        uint256 _minGoalToCollect,
        uint256 _endTime
    ) public returns (uint256) {
        if (_minGoalToCollect == 0) revert InvalidGoal();
        if (_endTime <= block.timestamp) revert InvalidEndTime();

        uint256 campaignId = campaignCounter++;

        campaigns[campaignId] = Campaign({
            adminCampaign: msg.sender,
            minGoalToCollect: _minGoalToCollect,
            endTime: _endTime,
            collectedFunds: 0,
            numberOfContributors: 0
        });

        emit CampaignCreated(campaignId, msg.sender, _minGoalToCollect, _endTime);
        return campaignId;
    }

    /**
     * @dev Contributes USDC to a specific campaign
     * @param campaignId ID of the campaign
     * @param amount Amount of USDC to contribute
     */
    function contribute(uint256 campaignId, uint256 amount) public 
        validCampaign(campaignId) 
        campaignActive(campaignId) 
    {
        if (amount == 0) revert InvalidAmount();
        if (contributions[campaignId][msg.sender] > 0) revert AlreadyDonated();

        Campaign storage campaign = campaigns[campaignId];
        
        // Update state before transfer
        contributions[campaignId][msg.sender] = amount;
        campaign.collectedFunds += amount;
        campaign.numberOfContributors++;

        // Perform transfer last
        bool success = IERC20(usdcTokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "USDC transfer failed");

        emit Contribution(campaignId, msg.sender, amount);
    }

    /**
     * @dev Withdraws contribution from an active campaign
     * @param campaignId ID of the campaign
     */
    function withdraw(uint256 campaignId) public 
        validCampaign(campaignId) 
        campaignActive(campaignId) 
    {
        uint256 amountDonated = contributions[campaignId][msg.sender];
        if (amountDonated == 0) revert NotExistingContribution();

        Campaign storage campaign = campaigns[campaignId];
        
        // Update state before transfer
        contributions[campaignId][msg.sender] = 0;
        campaign.collectedFunds -= amountDonated;
        campaign.numberOfContributors--;

        // Perform transfer last
        bool success = IERC20(usdcTokenAddress).transfer(msg.sender, amountDonated);
        require(success, "USDC transfer failed");

        emit Withdraw(campaignId, msg.sender, amountDonated);
    }

    /**
     * @dev Claims funds for a successful campaign
     * @param campaignId ID of the campaign
     */
    function claimFunds(uint256 campaignId) public 
        validCampaign(campaignId) 
        onlyAdmin(campaignId) 
        campaignEnded(campaignId) 
    {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.collectedFunds < campaign.minGoalToCollect) revert GoalNotReached();

        uint256 amountToTransfer = campaign.collectedFunds;

        // Perform transfer last
        bool success = IERC20(usdcTokenAddress).transfer(campaign.adminCampaign, amountToTransfer);
        require(success, "USDC transfer failed");

        emit FundsClaimed(campaignId, campaign.adminCampaign, amountToTransfer);
    }

    /**
     * @dev Emergency withdrawal for failed campaigns
     * @param campaignId ID of the campaign
     */
    function emergencyWithdraw(uint256 campaignId) public 
        validCampaign(campaignId) 
        campaignEnded(campaignId) 
    {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.collectedFunds >= campaign.minGoalToCollect) revert GoalReached();

        uint256 amountDonated = contributions[campaignId][msg.sender];
        if (amountDonated == 0) revert NotExistingContribution();

        // Update state before transfer
        contributions[campaignId][msg.sender] = 0;
        campaign.collectedFunds -= amountDonated;
        campaign.numberOfContributors--;

        // Perform transfer last
        bool success = IERC20(usdcTokenAddress).transfer(msg.sender, amountDonated);
        require(success, "USDC transfer failed");

        emit EmergencyWithdraw(campaignId, msg.sender, amountDonated);
    }
}