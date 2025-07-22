// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    GovToken govToken;
    TimeLock timelock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.revokeRole(adminRole, address(this));

        box = new Box();
        box.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalID = governor.propose(targets, values, calldatas, description);

        // View the state of the proposal
        console.log("Proposal State:", uint256(governor.state(proposalID)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State:", uint256(governor.state(proposalID)));

        // 2. Vote on the proposal
        string memory reason = "I support this proposal";

        uint8 voteWay = 1; // Vote in favor
        vm.prank(USER);
        governor.castVoteWithReason(proposalID, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Wait the minimum delay
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the proposal
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log("Box Value:", box.getNumber());
    }

    function testProposalStates() public {
        uint256 valueToStore = 777;
        string memory description = "Test proposal states";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. Create proposal - should be in Pending state
        uint256 proposalID = governor.propose(targets, values, calldatas, description);
        assertEq(uint256(governor.state(proposalID)), 0); // Pending

        // 2. After voting delay - should be Active
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalID)), 1); // Active

        // 3. Vote and advance to end of voting period - should be Succeeded
        vm.prank(USER);
        governor.castVote(proposalID, 1); // Vote in favor

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalID)), 4); // Succeeded
    }

    function testProposalWithInsufficientVotes() public {
        // Test a proposal that fails due to insufficient votes
        uint256 valueToStore = 555;
        string memory description = "This proposal should fail";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        uint256 proposalID = governor.propose(targets, values, calldatas, description);

        // Wait for voting to become active
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote against the proposal
        vm.prank(USER);
        governor.castVote(proposalID, 0); // Vote against

        // Advance past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Proposal should be defeated
        assertEq(uint256(governor.state(proposalID)), 3); // Defeated
    }

    function testGovTokenFunctions() public {
        // Test the mint function that wasn't covered
        address newUser = makeAddr("newUser");
        uint256 mintAmount = 50 ether;

        govToken.mint(newUser, mintAmount);
        assertEq(govToken.balanceOf(newUser), mintAmount);

        // Test delegate function
        vm.prank(newUser);
        govToken.delegate(newUser);
        assertEq(govToken.getVotes(newUser), mintAmount);

        // Test nonces function
        uint256 nonce = govToken.nonces(newUser);
        assertEq(nonce, 0);
    }

    function testGovernorSettings() public {
        // Test governor configuration functions
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 0);

        // Test quorum requirements - need to use a past block number
        vm.roll(block.number + 1);
        uint256 pastBlock = block.number - 1;
        uint256 quorum = governor.quorum(pastBlock);
        assertTrue(quorum > 0);
    }

    function testMultipleProposals() public {
        // Test creating multiple proposals
        string memory description1 = "First proposal";
        string memory description2 = "Second proposal";

        bytes memory encodedCall1 = abi.encodeWithSignature("store(uint256)", 111);
        bytes memory encodedCall2 = abi.encodeWithSignature("store(uint256)", 222);

        uint256[] memory values1 = new uint256[](1);
        bytes[] memory calldatas1 = new bytes[](1);
        address[] memory targets1 = new address[](1);

        values1[0] = 0;
        calldatas1[0] = encodedCall1;
        targets1[0] = address(box);

        uint256[] memory values2 = new uint256[](1);
        bytes[] memory calldatas2 = new bytes[](1);
        address[] memory targets2 = new address[](1);

        values2[0] = 0;
        calldatas2[0] = encodedCall2;
        targets2[0] = address(box);

        uint256 proposal1 = governor.propose(targets1, values1, calldatas1, description1);
        uint256 proposal2 = governor.propose(targets2, values2, calldatas2, description2);

        assertTrue(proposal1 != proposal2);
        assertEq(uint256(governor.state(proposal1)), 0); // Pending
        assertEq(uint256(governor.state(proposal2)), 0); // Pending
    }

    function testTimelockDirectInteraction() public {
        // Test that timelock requires proper roles
        bytes memory data = abi.encodeWithSignature("store(uint256)", 999);

        vm.expectRevert();
        timelock.execute(address(box), 0, data, bytes32(0), bytes32(0));
    }

    function testProposalNeedsQueuing() public {
        uint256 valueToStore = 333;
        string memory description = "Test queuing requirement";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        uint256 proposalID = governor.propose(targets, values, calldatas, description);

        // Test that proposal needs queuing
        assertTrue(governor.proposalNeedsQueuing(proposalID));
    }
}
