// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyGovernor} from "../src/MyGovernor.sol";

contract VoteOnProposal is Script {
    // Contract addresses (replace with your deployed addresses)
    address constant GOVERNOR_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // Replace

    // Voting parameters
    uint256 constant PROPOSAL_ID = 0; // Replace with actual proposal ID
    uint8 constant VOTE_WAY = 1; // 0 = Against, 1 = For, 2 = Abstain
    string constant REASON = "I support this proposal";

    function run() external {
        uint256 voterPrivateKey = vm.envUint("PRIVATE_KEY");
        address voter = vm.addr(voterPrivateKey);

        MyGovernor governor = MyGovernor(payable(GOVERNOR_ADDRESS));

        console.log("Voter address:", voter);
        console.log("Proposal ID:", PROPOSAL_ID);
        console.log("Current proposal state:", uint256(governor.state(PROPOSAL_ID)));

        // Check if proposal is in voting state (state 1 = Active)
        require(uint256(governor.state(PROPOSAL_ID)) == 1, "Proposal not in voting state");

        vm.startBroadcast(voterPrivateKey);

        console.log("Casting vote...");
        governor.castVoteWithReason(PROPOSAL_ID, VOTE_WAY, REASON);
        console.log("Vote cast successfully!");

        vm.stopBroadcast();

        // Get voting results
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(PROPOSAL_ID);

        console.log("\n=== VOTING RESULTS ===");
        console.log("Against votes:", againstVotes / 1e18);
        console.log("For votes:", forVotes / 1e18);
        console.log("Abstain votes:", abstainVotes / 1e18);

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Wait for voting period to end");
        console.log("2. Run QueueAndExecute script if proposal succeeds");
    }
}
