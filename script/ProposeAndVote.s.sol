// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract ProposeAndVote is Script {
    // Contract addresses (replace with your deployed addresses)
    address constant GOVERNOR_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // Replace
    address constant BOX_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F; // Replace
    address constant GOV_TOKEN_ADDRESS = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853; // Replace

    // Proposal parameters
    uint256 constant NEW_STORE_VALUE = 77;
    string constant PROPOSAL_DESCRIPTION = "Proposal #1: Store 77 in the Box";

    function run() external {
        uint256 voterPrivateKey = vm.envUint("PRIVATE_KEY");
        address voter = vm.addr(voterPrivateKey);

        MyGovernor governor = MyGovernor(payable(GOVERNOR_ADDRESS));
        Box box = Box(BOX_ADDRESS);
        GovToken govToken = GovToken(GOV_TOKEN_ADDRESS);

        console.log("Voter address:", voter);
        console.log("Voter token balance:", govToken.balanceOf(voter) / 1e18);
        console.log("Voter voting power:", govToken.getVotes(voter) / 1e18);
        console.log("Current box value:", box.getNumber());

        vm.startBroadcast(voterPrivateKey);

        // 1. Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = BOX_ADDRESS;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("store(uint256)", NEW_STORE_VALUE);

        console.log("Creating proposal...");
        uint256 proposalId = governor.propose(targets, values, calldatas, PROPOSAL_DESCRIPTION);
        console.log("Proposal created with ID:", proposalId);
        console.log("Proposal state:", uint256(governor.state(proposalId)));

        vm.stopBroadcast();

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Wait for voting delay to pass (7200 blocks ~1 day)");
        console.log("2. Run VoteOnProposal script with proposal ID:", proposalId);
        console.log("3. Wait for voting period to end");
        console.log("4. Run QueueAndExecute script");
    }
}
