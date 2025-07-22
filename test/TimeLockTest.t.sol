// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract TimeLockTest is Test {
    TimeLock timelock;

    address public USER = makeAddr("user");
    uint256 public constant MIN_DELAY = 3600;

    address[] proposers;
    address[] executors;

    function setUp() public {
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
    }

    function testTimeLockDeployment() public view {
        assertEq(timelock.getMinDelay(), MIN_DELAY);
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    function testRoleManagement() public {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();

        // Grant roles
        timelock.grantRole(proposerRole, USER);
        timelock.grantRole(executorRole, USER);

        assertTrue(timelock.hasRole(proposerRole, USER));
        assertTrue(timelock.hasRole(executorRole, USER));

        // Revoke roles
        timelock.revokeRole(proposerRole, USER);
        timelock.revokeRole(executorRole, USER);

        assertFalse(timelock.hasRole(proposerRole, USER));
        assertFalse(timelock.hasRole(executorRole, USER));
    }
}
