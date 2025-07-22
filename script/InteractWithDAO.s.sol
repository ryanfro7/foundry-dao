// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract InteractWithDAO is Script {
    // Contract addresses (replace with your deployed addresses)
    address constant GOVERNOR_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // Replace
    address constant BOX_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F; // Replace
    address constant GOV_TOKEN_ADDRESS = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853; // Replace
    address constant TIMELOCK_ADDRESS = 0x2e234DAe75C793f67A35089C9d99245E1C58470b; // Replace

    function run() external view {
        checkDAOStatus();
    }

    function checkDAOStatus() public view {
        MyGovernor governor = MyGovernor(payable(GOVERNOR_ADDRESS));
        Box box = Box(BOX_ADDRESS);
        GovToken govToken = GovToken(GOV_TOKEN_ADDRESS);
        TimeLock timelock = TimeLock(payable(TIMELOCK_ADDRESS));

        console.log("=== DAO STATUS ===");
        console.log("Governor:", GOVERNOR_ADDRESS);
        console.log("Box:", BOX_ADDRESS);
        console.log("GovToken:", GOV_TOKEN_ADDRESS);
        console.log("TimeLock:", TIMELOCK_ADDRESS);
        console.log("");

        console.log("=== GOVERNANCE SETTINGS ===");
        console.log("Voting Delay:", governor.votingDelay(), "blocks");
        console.log("Voting Period:", governor.votingPeriod(), "blocks");
        console.log("Proposal Threshold:", governor.proposalThreshold() / 1e18, "tokens");
        console.log("Timelock Delay:", timelock.getMinDelay(), "seconds");
        console.log("");

        console.log("=== BOX STATUS ===");
        console.log("Current Value:", box.getNumber());
        console.log("Owner:", box.owner());
        console.log("");

        console.log("=== TOKEN INFO ===");
        console.log("Token Name:", govToken.name());
        console.log("Token Symbol:", govToken.symbol());
        console.log("Total Supply:", govToken.totalSupply() / 1e18, "tokens");
        console.log("");
    }

    function checkUserStatus(address user) external view {
        GovToken govToken = GovToken(GOV_TOKEN_ADDRESS);

        console.log("=== USER STATUS ===");
        console.log("User Address:", user);
        console.log("Token Balance:", govToken.balanceOf(user) / 1e18, "tokens");
        console.log("Voting Power:", govToken.getVotes(user) / 1e18, "votes");
        console.log("Delegate:", govToken.delegates(user));
        console.log("");
    }

    function mintTokensTo(address recipient, uint256 amount) external {
        uint256 minterPrivateKey = vm.envUint("PRIVATE_KEY");

        GovToken govToken = GovToken(GOV_TOKEN_ADDRESS);

        vm.startBroadcast(minterPrivateKey);
        govToken.mint(recipient, amount);
        vm.stopBroadcast();

        console.log("Minted", amount / 1e18, "tokens to", recipient);
        console.log("New balance:", govToken.balanceOf(recipient) / 1e18, "tokens");
    }

    function delegateVotingPower(address delegatee) external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");

        GovToken govToken = GovToken(GOV_TOKEN_ADDRESS);

        vm.startBroadcast(userPrivateKey);
        govToken.delegate(delegatee);
        vm.stopBroadcast();

        console.log("Delegated voting power to:", delegatee);
        console.log("Delegatee voting power:", govToken.getVotes(delegatee) / 1e18, "votes");
    }
}
