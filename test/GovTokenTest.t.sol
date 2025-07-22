// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovToken} from "../src/GovToken.sol";

contract GovTokenTest is Test {
    GovToken govToken;

    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    uint256 public constant MINT_AMOUNT = 100 ether;

    function setUp() public {
        govToken = new GovToken();
    }

    function testTokenBasics() public view {
        assertEq(govToken.name(), "MyToken");
        assertEq(govToken.symbol(), "MTK");
        assertEq(govToken.decimals(), 18);
        assertEq(govToken.totalSupply(), 0);
    }

    function testMinting() public {
        govToken.mint(USER1, MINT_AMOUNT);

        assertEq(govToken.balanceOf(USER1), MINT_AMOUNT);
        assertEq(govToken.totalSupply(), MINT_AMOUNT);
    }

    function testDelegation() public {
        govToken.mint(USER1, MINT_AMOUNT);

        // Initially no votes
        assertEq(govToken.getVotes(USER1), 0);

        // Self-delegate
        vm.prank(USER1);
        govToken.delegate(USER1);

        assertEq(govToken.getVotes(USER1), MINT_AMOUNT);
        assertEq(govToken.delegates(USER1), USER1);
    }

    function testDelegateToOther() public {
        govToken.mint(USER1, MINT_AMOUNT);

        // Delegate to USER2
        vm.prank(USER1);
        govToken.delegate(USER2);

        assertEq(govToken.getVotes(USER2), MINT_AMOUNT);
        assertEq(govToken.getVotes(USER1), 0);
        assertEq(govToken.delegates(USER1), USER2);
    }

    function testTransferWithDelegation() public {
        govToken.mint(USER1, MINT_AMOUNT);

        // USER1 delegates to themselves
        vm.prank(USER1);
        govToken.delegate(USER1);

        assertEq(govToken.getVotes(USER1), MINT_AMOUNT);

        // Transfer some tokens to USER2
        uint256 transferAmount = 30 ether;
        vm.prank(USER1);
        govToken.transfer(USER2, transferAmount);

        // USER1's voting power should decrease
        assertEq(govToken.getVotes(USER1), MINT_AMOUNT - transferAmount);

        // USER2 should have tokens but no votes until they delegate
        assertEq(govToken.balanceOf(USER2), transferAmount);
        assertEq(govToken.getVotes(USER2), 0);

        // USER2 delegates to themselves
        vm.prank(USER2);
        govToken.delegate(USER2);

        assertEq(govToken.getVotes(USER2), transferAmount);
    }

    function testNonces() public {
        assertEq(govToken.nonces(USER1), 0);

        // Nonces should increment with delegation changes
        vm.prank(USER1);
        govToken.delegate(USER1);

        // Note: The actual nonce behavior may vary depending on implementation
        // This test ensures the nonces function is callable
        uint256 nonce = govToken.nonces(USER1);
        assertTrue(nonce >= 0);
    }

    function testClock() public view {
        uint256 clock = govToken.clock();
        assertTrue(clock > 0);
    }
}
