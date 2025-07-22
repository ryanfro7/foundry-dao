// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";

contract QueueAndExecute is Script {
    // Contract addresses (replace with your deployed addresses)
    address constant GOVERNOR_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // Replace
    address constant BOX_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F; // Replace

    // Proposal parameters (must match the original proposal)
    uint256 constant NEW_STORE_VALUE = 77;
    string constant PROPOSAL_DESCRIPTION = "Proposal #1: Store 77 in the Box";

    function run() external {
        uint256 executorPrivateKey = vm.envUint("PRIVATE_KEY");
        address executor = vm.addr(executorPrivateKey);

        MyGovernor governor = MyGovernor(payable(GOVERNOR_ADDRESS));
        Box box = Box(BOX_ADDRESS);

        console.log("Executor address:", executor);
        console.log("Current box value:", box.getNumber());

        // Recreate proposal parameters
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = BOX_ADDRESS;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", NEW_STORE_VALUE);

        bytes32 descriptionHash = keccak256(abi.encodePacked(PROPOSAL_DESCRIPTION));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        console.log("Proposal ID:", proposalId);
        console.log("Current proposal state:", uint256(governor.state(proposalId)));

        // Check if proposal succeeded (state 4 = Succeeded)
        require(uint256(governor.state(proposalId)) == 4, "Proposal did not succeed");

        vm.startBroadcast(executorPrivateKey);

        // Queue the proposal
        console.log("Queueing proposal...");
        governor.queue(targets, values, calldatas, descriptionHash);
        console.log("Proposal queued successfully!");
        console.log("New proposal state:", uint256(governor.state(proposalId)));

        vm.stopBroadcast();

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Wait for timelock delay (3600 seconds = 1 hour)");
        console.log("2. Run this script again to execute the proposal");
        console.log("3. Or manually call the execute function after delay");
    }

    function executeProposal() external {
        uint256 executorPrivateKey = vm.envUint("PRIVATE_KEY");

        MyGovernor governor = MyGovernor(payable(GOVERNOR_ADDRESS));
        Box box = Box(BOX_ADDRESS);

        console.log("Current box value before execution:", box.getNumber());

        // Recreate proposal parameters
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = BOX_ADDRESS;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", NEW_STORE_VALUE);

        bytes32 descriptionHash = keccak256(abi.encodePacked(PROPOSAL_DESCRIPTION));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        console.log("Proposal state:", uint256(governor.state(proposalId)));

        // Check if proposal is queued (state 5 = Queued)
        require(uint256(governor.state(proposalId)) == 5, "Proposal not queued or delay not passed");

        vm.startBroadcast(executorPrivateKey);

        // Execute the proposal
        console.log("Executing proposal...");
        governor.execute(targets, values, calldatas, descriptionHash);
        console.log("Proposal executed successfully!");

        vm.stopBroadcast();

        console.log("Box value after execution:", box.getNumber());
        console.log("Final proposal state:", uint256(governor.state(proposalId)));
    }
}
