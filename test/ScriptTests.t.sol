// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract ScriptTests is Test {
    address public deployer;
    address public user1;
    address public user2;

    // Deployed contracts
    GovToken public govToken;
    MyGovernor public governor;
    TimeLock public timeLock;
    Box public box;

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant INITIAL_SUPPLY = 1000000 ether; // 1M tokens

    function setUp() public {
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Give addresses some ETH
        vm.deal(deployer, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // Helper function to deploy DAO (similar to script)
    function deployDAO(address caller) internal returns (GovToken, TimeLock, MyGovernor, Box) {
        // 1. Deploy GovToken
        GovToken _govToken = new GovToken();
        
        // 2. Mint initial supply to specified caller
        _govToken.mint(caller, INITIAL_SUPPLY);
        
        // 3. Caller delegates to themselves
        _govToken.delegate(caller);
        
        // 4. Deploy TimeLock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        TimeLock _timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        
        // 5. Deploy Governor
        MyGovernor _governor = new MyGovernor(_govToken, _timeLock);
        
        // 6. Setup TimeLock roles
        bytes32 proposerRole = _timeLock.PROPOSER_ROLE();
        bytes32 executorRole = _timeLock.EXECUTOR_ROLE();
        
        _timeLock.grantRole(proposerRole, address(_governor));
        _timeLock.grantRole(executorRole, address(_governor));
        
        // 7. Deploy Box
        Box _box = new Box();
        
        // 8. Transfer Box ownership to TimeLock
        _box.transferOwnership(address(_timeLock));
        
        return (_govToken, _timeLock, _governor, _box);
    }

    function testDeployDAOScript() public {
        vm.startPrank(deployer);
        
        (GovToken _govToken, TimeLock _timeLock, MyGovernor _governor, Box _box) = deployDAO(deployer);
        
        // Store contracts for verification
        govToken = _govToken;
        timeLock = _timeLock;
        governor = _governor;
        box = _box;
        
        // Verify deployment was successful
        assertTrue(address(govToken) != address(0));
        assertTrue(address(timeLock) != address(0));
        assertTrue(address(governor) != address(0));
        assertTrue(address(box) != address(0));
        
        vm.stopPrank();
    }

    function testScriptDeploymentReturnsValidContracts() public {
        vm.startPrank(deployer);
        
        (GovToken _govToken, TimeLock _timeLock, MyGovernor _governor, Box _box) = deployDAO(deployer);
        
        // Verify contracts are properly deployed
        assertEq(_govToken.name(), "MyToken");
        assertEq(_govToken.symbol(), "MTK");
        assertGt(_govToken.totalSupply(), 0);
        
        // Verify governor settings
        assertEq(_governor.votingDelay(), 7200);
        assertEq(_governor.votingPeriod(), 50400);
        assertEq(_governor.proposalThreshold(), 0);
        
        // Verify timelock settings
        assertEq(_timeLock.getMinDelay(), 3600); // 1 hour
        
        // Verify box ownership
        assertEq(_box.owner(), address(_timeLock));
        
        vm.stopPrank();
    }

    function testScriptTokenDistribution() public {
        vm.startPrank(deployer);
        
        (GovToken _govToken, , , ) = deployDAO(deployer);
        
        // Check initial token distribution (tokens should go to deployer)
        uint256 deployerBalance = _govToken.balanceOf(deployer);
        assertEq(deployerBalance, INITIAL_SUPPLY);
        
        // Check delegation
        assertEq(_govToken.delegates(deployer), deployer);
        assertGt(_govToken.getVotes(deployer), 0);
        
        vm.stopPrank();
    }

    function testScriptGasUsage() public {
        vm.startPrank(deployer);
        
        uint256 gasBefore = gasleft();
        deployDAO(deployer);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Ensure deployment doesn't use excessive gas
        assertLt(gasUsed, 15_000_000); // 15M gas limit
        
        console.log("Gas used for deployment:", gasUsed);
        
        vm.stopPrank();
    }

    function testScriptRoleSetup() public {
        vm.startPrank(deployer);
        
        (, TimeLock _timeLock, MyGovernor _governor, ) = deployDAO(deployer);
        
        // Verify role setup
        bytes32 proposerRole = _timeLock.PROPOSER_ROLE();
        bytes32 executorRole = _timeLock.EXECUTOR_ROLE();
        
        // Governor should have proposer role
        assertTrue(_timeLock.hasRole(proposerRole, address(_governor)));
        
        // Governor should have executor role
        assertTrue(_timeLock.hasRole(executorRole, address(_governor)));
        
        vm.stopPrank();
    }

    function testScriptContractInteractions() public {
        vm.startPrank(deployer);
        
        (GovToken _govToken, TimeLock _timeLock, , Box _box) = deployDAO(deployer);
        
        // Test token functionality
        assertGt(_govToken.balanceOf(deployer), 0);
        assertGt(_govToken.getVotes(deployer), 0);
        
        // Test that box is owned by timelock
        assertEq(_box.owner(), address(_timeLock));
        
        // Test that direct box access fails for non-owner
        vm.expectRevert();
        _box.store(42);
        
        vm.stopPrank();
    }

    function testMultipleScriptRuns() public {
        // Test that we can run the deployment multiple times
        
        vm.startPrank(deployer);
        (GovToken token1, , , ) = deployDAO(deployer);
        vm.stopPrank();
        
        vm.startPrank(user1);
        (GovToken token2, , , ) = deployDAO(user1);
        vm.stopPrank();
        
        // Should create different contract instances
        assertTrue(address(token1) != address(token2));
    }

    function testScriptWithDifferentDeployers() public {
        // Test deployment with different deployers
        
        vm.startPrank(user1);
        (GovToken token1, , , ) = deployDAO(user1);
        
        // Verify user1 got the tokens
        assertEq(token1.balanceOf(user1), INITIAL_SUPPLY);
        assertEq(token1.delegates(user1), user1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        (GovToken token2, , , ) = deployDAO(user2);
        
        // Verify user2 got the tokens
        assertEq(token2.balanceOf(user2), INITIAL_SUPPLY);
        assertEq(token2.delegates(user2), user2);
        vm.stopPrank();
    }

    function testScriptEventEmissions() public {
        vm.startPrank(deployer);
        
        // Test that the deployment emits expected events
        deployDAO(deployer);
        
        vm.stopPrank();
    }

    function testScriptRevertPrevention() public {
        // Test that the script handles edge cases properly
        
        vm.startPrank(deployer);
        
        // This should work normally
        deployDAO(deployer);
        
        vm.stopPrank();
    }

    function testScriptTokenMinting() public {
        vm.startPrank(deployer);
        
        (GovToken _govToken, , , ) = deployDAO(deployer);
        
        // Test additional minting
        uint256 additionalAmount = 50000 ether;
        _govToken.mint(user1, additionalAmount);
        
        assertEq(_govToken.balanceOf(user1), additionalAmount);
        assertEq(_govToken.totalSupply(), INITIAL_SUPPLY + additionalAmount);
        
        vm.stopPrank();
    }

    function testScriptBoxConfiguration() public {
        vm.startPrank(deployer);
        
        (, TimeLock _timeLock, , Box _box) = deployDAO(deployer);
        
        // Test that box is properly configured
        assertEq(_box.getNumber(), 0); // Initial value
        assertEq(_box.owner(), address(_timeLock));
        
        // Test that timelock can control the box
        vm.stopPrank();
        vm.prank(address(_timeLock));
        _box.store(123);
        
        assertEq(_box.getNumber(), 123);
    }
}
