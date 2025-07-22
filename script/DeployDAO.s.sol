// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";

contract DeployDAO is Script {
    // Configuration
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant INITIAL_SUPPLY = 1000000 ether; // 1M tokens

    // Contracts
    GovToken govToken;
    TimeLock timelock;
    MyGovernor governor;
    Box box;

    function run() external returns (GovToken, TimeLock, MyGovernor, Box) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying DAO with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy GovToken
        console.log("Deploying GovToken...");
        govToken = new GovToken();
        console.log("GovToken deployed at:", address(govToken));

        // 2. Mint initial supply to deployer
        govToken.mint(deployer, INITIAL_SUPPLY);
        console.log("Minted", INITIAL_SUPPLY / 1e18, "tokens to deployer");

        // 3. Deployer delegates to themselves to get voting power
        govToken.delegate(deployer);
        console.log("Deployer delegated voting power to themselves");

        // 4. Deploy TimeLock
        console.log("Deploying TimeLock...");
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        console.log("TimeLock deployed at:", address(timelock));

        // 5. Deploy Governor
        console.log("Deploying MyGovernor...");
        governor = new MyGovernor(govToken, timelock);
        console.log("MyGovernor deployed at:", address(governor));

        // 6. Setup TimeLock roles
        console.log("Setting up TimeLock roles...");
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Grant roles to the governor
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        console.log("Granted proposer and executor roles to governor");

        // Revoke admin role from deployer (optional - for decentralization)
        // timelock.revokeRole(adminRole, deployer);
        // console.log("Revoked admin role from deployer");
        console.log("Admin role kept by deployer for now");
        console.logBytes32(adminRole);

        // 7. Deploy Box (the contract to be governed)
        console.log("Deploying Box...");
        box = new Box();
        console.log("Box deployed at:", address(box));

        // 8. Transfer Box ownership to TimeLock
        box.transferOwnership(address(timelock));
        console.log("Transferred Box ownership to TimeLock");

        vm.stopBroadcast();

        // Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("GovToken:", address(govToken));
        console.log("TimeLock:", address(timelock));
        console.log("MyGovernor:", address(governor));
        console.log("Box:", address(box));
        console.log("Deployer tokens:", govToken.balanceOf(deployer) / 1e18);
        console.log("Deployer voting power:", govToken.getVotes(deployer) / 1e18);

        return (govToken, timelock, governor, box);
    }
}
