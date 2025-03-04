// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MCPDistribution is Ownable {
    IERC20 public mcpToken;

    struct Stakeholder {
        uint256 percentage; // Percentage of distribution (out of 100)
        bool exists;        // Check if stakeholder exists
        bool approved;      // Approval for distribution
        bool votedToDestroy; // Approval for contract destruction
    }

    mapping(address => Stakeholder) public stakeholders;
    address[] public stakeholderList;
    uint256 public totalPercentage;
    uint256 public approvalCount;
    uint256 public destroyVotes;

    event StakeholderAdded(address indexed stakeholder, uint256 percentage);
    event TokensDistributed(uint256 amount);
    event ContractDestroyed();

    constructor(address _mcpToken, address initialOwner) Ownable(initialOwner) {
        mcpToken = IERC20(_mcpToken);
    }

    modifier onlyStakeholder() {
        require(stakeholders[msg.sender].exists, "Not a stakeholder");
        _;
    }

    function addStakeholder(address _stakeholder, uint256 _percentage) public onlyOwner {
        require(!stakeholders[_stakeholder].exists, "Already a stakeholder");
        require(totalPercentage + _percentage <= 100, "Total percentage exceeds 100");

        stakeholders[_stakeholder] = Stakeholder({
            percentage: _percentage,
            exists: true,
            approved: false,
            votedToDestroy: false
        });

        stakeholderList.push(_stakeholder);
        totalPercentage += _percentage;

        emit StakeholderAdded(_stakeholder, _percentage);
    }

    function approveDistribution() public onlyStakeholder {
        require(!stakeholders[msg.sender].approved, "Already approved");

        stakeholders[msg.sender].approved = true;
        approvalCount++;
    }

    function distributeTokens() public onlyOwner {
        require(approvalCount == stakeholderList.length, "All stakeholders must approve");

        uint256 balance = mcpToken.balanceOf(address(this));
        require(balance > 0, "No tokens to distribute");

        for (uint256 i = 0; i < stakeholderList.length; i++) {
            address stakeholder = stakeholderList[i];
            uint256 amount = (balance * stakeholders[stakeholder].percentage) / 100;
            require(mcpToken.transfer(stakeholder, amount), "Transfer failed");
            stakeholders[stakeholder].approved = false; // Reset approval
        }

        approvalCount = 0;
        emit TokensDistributed(balance);
    }

    function contractBalance() public view returns (uint256) {
        return mcpToken.balanceOf(address(this));
    }

    function voteToDestroy() public onlyStakeholder {
        require(!stakeholders[msg.sender].votedToDestroy, "Already voted");
        
        stakeholders[msg.sender].votedToDestroy = true;
        destroyVotes++;

        if (destroyVotes > stakeholderList.length / 2) {
            emit ContractDestroyed();

            uint256 balance = mcpToken.balanceOf(address(this));
            payable(owner()).transfer(balance);
        }


    }

}
