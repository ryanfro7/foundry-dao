// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";
import {TestDeployDAO} from "../script/TestDeployDAO.s.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract FuzzTests is Test {
    GovToken public govToken;
    MyGovernor public governor;
    TimeLock public timeLock;
    Box public box;
    
    address public deployer;
    address public constant SCRIPT_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    
    function setUp() public {
        deployer = makeAddr("deployer");
        vm.deal(deployer, 100 ether);
        
        // Deploy DAO using the script
        TestDeployDAO deployScript = new TestDeployDAO();
        (govToken, timeLock, governor, box) = deployScript.run();
        
        // Give some tokens to our test deployer for testing
        vm.prank(SCRIPT_DEPLOYER);
        govToken.transfer(deployer, 10000 ether);
        
        vm.prank(deployer);
        govToken.delegate(deployer);
    }

    // Fuzz test token minting with various amounts
    function testFuzz_TokenMinting(uint256 amount) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 1, 1e30); // 1 wei to 1e30 wei
        
        address recipient = makeAddr("recipient");
        
        vm.prank(SCRIPT_DEPLOYER);
        govToken.mint(recipient, amount);
        
        assertEq(govToken.balanceOf(recipient), amount);
        assertEq(govToken.totalSupply(), INITIAL_SUPPLY + amount);
    }

    // Fuzz test token delegation with random addresses
    function testFuzz_TokenDelegation(address delegatee) public {
        vm.assume(delegatee != address(0));
        vm.assume(delegatee.code.length == 0); // Not a contract
        
        vm.prank(deployer);
        govToken.delegate(delegatee);
        
        assertEq(govToken.delegates(deployer), delegatee);
        
        if (delegatee == deployer) {
            assertGt(govToken.getVotes(delegatee), 0);
        }
    }

    // Fuzz test token transfers with various amounts
    function testFuzz_TokenTransfer(uint256 amount, address recipient) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != deployer);
        vm.assume(recipient.code.length == 0);
        
        uint256 maxAmount = govToken.balanceOf(deployer);
        amount = bound(amount, 0, maxAmount);
        
        uint256 initialDeployerBalance = govToken.balanceOf(deployer);
        uint256 initialRecipientBalance = govToken.balanceOf(recipient);
        
        vm.prank(deployer);
        govToken.transfer(recipient, amount);
        
        assertEq(govToken.balanceOf(deployer), initialDeployerBalance - amount);
        assertEq(govToken.balanceOf(recipient), initialRecipientBalance + amount);
    }

    // Fuzz test proposal creation with random parameters
    function testFuzz_ProposalCreation(uint256 newValue) public {
        newValue = bound(newValue, 0, type(uint256).max);
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", newValue);
        
        string memory description = "Fuzz test proposal";
        
        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    // Fuzz test voting with different vote types
    function testFuzz_Voting(uint8 voteType) public {
        voteType = uint8(bound(voteType, 0, 2)); // 0=Against, 1=For, 2=Abstain
        
        // Create a proposal first
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);
        
        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");
        
        // Move past voting delay
        vm.roll(block.number + governor.votingDelay() + 1);
        
        // Cast vote
        vm.prank(deployer);
        governor.castVote(proposalId, voteType);
        
        // Check that vote was recorded
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        if (voteType == 0) {
            assertGt(againstVotes, 0);
        } else if (voteType == 1) {
            assertGt(forVotes, 0);
        } else {
            assertGt(abstainVotes, 0);
        }
    }

    // Fuzz test Box storage with various values
    function testFuzz_BoxStorageDirectly(uint256 value) public {
        // Test direct storage (should fail for non-owner)
        address randomUser = makeAddr("randomUser");
        
        vm.prank(randomUser);
        vm.expectRevert();
        box.store(value);
        
        // Test with timelock owner (should work)
        vm.prank(address(timeLock));
        box.store(value);
        
        assertEq(box.getNumber(), value);
    }

    // Fuzz test governance workflow with random values
    function testFuzz_GovernanceWorkflow(uint256 newValue) public {
        newValue = bound(newValue, 0, type(uint128).max); // Reasonable bounds
        
        // 1. Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", newValue);
        
        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Fuzz governance test");
        
        // 2. Move to voting period
        vm.roll(block.number + governor.votingDelay() + 1);
        
        // 3. Vote for the proposal
        vm.prank(deployer);
        governor.castVote(proposalId, 1); // Vote "For"
        
        // 4. Move past voting period
        vm.roll(block.number + governor.votingPeriod() + 1);
        
        // Check if proposal succeeded before trying to queue
        if (uint256(governor.state(proposalId)) == uint256(IGovernor.ProposalState.Succeeded)) {
            // 5. Queue the proposal
            governor.queue(targets, values, calldatas, keccak256(bytes("Fuzz governance test")));
            
            // 6. Wait for timelock delay
            vm.warp(block.timestamp + MIN_DELAY + 1);
            
            // 7. Execute the proposal
            governor.execute(targets, values, calldatas, keccak256(bytes("Fuzz governance test")));
            
            // 8. Verify the box was updated
            assertEq(box.getNumber(), newValue);
        }
    }

    // Fuzz test timelock delay with various timestamps
    function testFuzz_TimelockDelay(uint256 delay) public {
        delay = bound(delay, MIN_DELAY, 365 days); // Reasonable delay bounds
        
        // Create new timelock with custom delay
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(governor);
        executors[0] = address(governor);
        
        TimeLock customTimeLock = new TimeLock(delay, proposers, executors);
        
        assertEq(customTimeLock.getMinDelay(), delay);
    }

    // Fuzz test token distribution across multiple users
    function testFuzz_TokenDistribution(uint8 numUsers, uint256 amountPerUser) public {
        numUsers = uint8(bound(numUsers, 1, 20)); // 1-20 users
        amountPerUser = bound(amountPerUser, 1 ether, 10000 ether); // Reasonable amounts
        
        address[] memory users = new address[](numUsers);
        
        // Create users and distribute tokens
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            
            vm.prank(SCRIPT_DEPLOYER);
            govToken.mint(users[i], amountPerUser);
            
            vm.prank(users[i]);
            govToken.delegate(users[i]);
            
            assertEq(govToken.balanceOf(users[i]), amountPerUser);
            assertEq(govToken.getVotes(users[i]), amountPerUser);
        }
        
        // Check total supply increased correctly
        uint256 expectedTotalSupply = INITIAL_SUPPLY + (numUsers * amountPerUser);
        assertEq(govToken.totalSupply(), expectedTotalSupply);
    }

    // Fuzz test proposal with multiple targets
    function testFuzz_MultiTargetProposal(uint8 numTargets) public {
        numTargets = uint8(bound(numTargets, 1, 10)); // 1-10 targets
        
        address[] memory targets = new address[](numTargets);
        uint256[] memory values = new uint256[](numTargets);
        bytes[] memory calldatas = new bytes[](numTargets);
        
        // Create multiple targets (all pointing to box for simplicity)
        for (uint256 i = 0; i < numTargets; i++) {
            targets[i] = address(box);
            values[i] = 0;
            calldatas[i] = abi.encodeWithSignature("store(uint256)", i + 1);
        }
        
        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Multi-target proposal");
        
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    // Fuzz test voting power calculation
    function testFuzz_VotingPower(uint256 amount1, uint256 amount2, address user1, address user2) public {
        vm.assume(user1 != address(0) && user2 != address(0));
        vm.assume(user1 != user2);
        vm.assume(user1 != SCRIPT_DEPLOYER && user2 != SCRIPT_DEPLOYER);
        vm.assume(user1.code.length == 0 && user2.code.length == 0);
        
        amount1 = bound(amount1, 1 ether, 100000 ether);
        amount2 = bound(amount2, 1 ether, 100000 ether);
        
        uint256 totalSupplyBefore = govToken.totalSupply();
        
        // Mint tokens to users
        vm.prank(SCRIPT_DEPLOYER);
        govToken.mint(user1, amount1);
        
        vm.prank(SCRIPT_DEPLOYER);
        govToken.mint(user2, amount2);
        
        // Self-delegate
        vm.prank(user1);
        govToken.delegate(user1);
        
        vm.prank(user2);
        govToken.delegate(user2);
        
        // Check voting power
        assertEq(govToken.getVotes(user1), amount1);
        assertEq(govToken.getVotes(user2), amount2);
        
        // Check total supply increased correctly
        assertEq(govToken.totalSupply(), totalSupplyBefore + amount1 + amount2);
        
        // User with more tokens should have more voting power
        if (amount1 > amount2) {
            assertGt(govToken.getVotes(user1), govToken.getVotes(user2));
        } else if (amount2 > amount1) {
            assertGt(govToken.getVotes(user2), govToken.getVotes(user1));
        } else {
            assertEq(govToken.getVotes(user1), govToken.getVotes(user2));
        }
    }

    // Fuzz test proposal execution timing
    function testFuzz_ProposalExecutionTiming(uint256 waitTime) public {
        waitTime = bound(waitTime, 0, MIN_DELAY * 2);
        
        // Create and pass a proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);
        
        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Timing test");
        
        // Move through voting
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(deployer);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        
        // Only proceed if proposal succeeded
        if (uint256(governor.state(proposalId)) == uint256(IGovernor.ProposalState.Succeeded)) {
            // Queue the proposal
            governor.queue(targets, values, calldatas, keccak256(bytes("Timing test")));
            
            // Wait for specified time
            vm.warp(block.timestamp + waitTime);
            
            // Try to execute
            if (waitTime >= MIN_DELAY) {
                // Should succeed
                governor.execute(targets, values, calldatas, keccak256(bytes("Timing test")));
                assertEq(box.getNumber(), 42);
            } else {
                // Should fail
                vm.expectRevert();
                governor.execute(targets, values, calldatas, keccak256(bytes("Timing test")));
            }
        }
    }
}
