# Foundry DAO

A complete Decentralized Autonomous Organization (DAO) implementation built with Foundry, featuring governance tokens, timelock controls, and comprehensive testing.

This project was built as part of the **Cyfrin Advanced Foundry Course**. Special thanks to **Patrick Collins** for creating such an excellent educational resource that makes blockchain development accessible to everyone.

## Project Overview

This project implements a DAO with the following features:

- **ERC20 Governance Token**: Voting power based on token holdings
- **Governor Contract**: Handles proposals, voting, and execution
- **Timelock Controller**: Adds delay between proposal success and execution
- **Target Contract (Box)**: Example contract controlled by the DAO
- **Deployment Scripts**: Complete automation for deployment and interaction

## Project Structure

```
foundry-dao/
├── src/
│   ├── Box.sol              # Example contract controlled by DAO
│   ├── GovToken.sol         # ERC20 governance token with voting
│   ├── MyGovernor.sol       # Main governor contract
│   └── TimeLock.sol         # Timelock controller
├── test/
│   ├── BoxTest.t.sol        # Box contract tests
│   ├── GovTokenTest.t.sol   # Governance token tests
│   ├── MyGovernorTest.t.sol # Complete DAO workflow tests
│   └── TimeLockTest.t.sol   # Timelock functionality tests
├── script/
│   ├── DeployDAO.s.sol      # Complete DAO deployment
│   ├── ProposeAndVote.s.sol # Create governance proposals
│   ├── VoteOnProposal.s.sol # Cast votes on proposals
│   ├── QueueAndExecute.s.sol # Queue and execute proposals
│   ├── InteractWithDAO.s.sol # Utility functions
│   └── TestDeployDAO.s.sol  # Local testing deployment
└── lib/                     # Dependencies (OpenZeppelin, Forge Std)
```

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd foundry-dao

# Install dependencies
forge install

# Run tests
forge test

# Check test coverage
forge coverage
```

### Local Development

```bash
# Start local Anvil node
anvil

# Deploy to local network (in another terminal)
forge script script/TestDeployDAO.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## DAO Architecture

### Core Components

1. **GovToken** (`src/GovToken.sol`)
   - ERC20 token with voting capabilities
   - Built on OpenZeppelin's ERC20Votes
   - Includes delegation functionality

2. **MyGovernor** (`src/MyGovernor.sol`)
   - OpenZeppelin Governor-based implementation
   - Voting delay: 7,200 blocks (~1 day)
   - Voting period: 50,400 blocks (~1 week)
   - Quorum: 4% of total supply

3. **TimeLock** (`src/TimeLock.sol`)
   - OpenZeppelin TimelockController
   - 1-hour execution delay
   - Role-based access control
   - Prevents immediate execution after vote

4. **Box** (`src/Box.sol`)
   - Example target contract
   - Simple storage functionality
   - Owned by TimeLock (controlled by DAO)

### Governance Flow

```
1. Token Holder Creates Proposal
   ↓
2. Voting Delay (1 day)
   ↓
3. Voting Period (1 week)
   ↓
4. Proposal Succeeds/Fails
   ↓
5. Queue in Timelock (if succeeded)
   ↓
6. Execution Delay (1 hour)
   ↓
7. Execute Proposal
```

## Testing

The project includes comprehensive tests with **92% coverage**:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract MyGovernorTest

# Generate coverage report
forge coverage
```

## Deployment & Scripts

### Environment Setup

Create a `.env` file in the project root:

```bash
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### Deployment Scripts

#### 1. Deploy Complete DAO

```bash
# Deploy to testnet
forge script script/DeployDAO.s.sol --rpc-url $RPC_URL --broadcast --verify

# Deploy locally for testing
forge script script/TestDeployDAO.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

#### 2. Create a Proposal

```bash
# Update contract addresses in script first
forge script script/ProposeAndVote.s.sol --rpc-url $RPC_URL --broadcast
```

#### 3. Vote on Proposal

```bash
# Update PROPOSAL_ID in script first
forge script script/VoteOnProposal.s.sol --rpc-url $RPC_URL --broadcast
```

#### 4. Queue and Execute

```bash
# Queue the proposal
forge script script/QueueAndExecute.s.sol --rpc-url $RPC_URL --broadcast

# Execute after timelock delay
forge script script/QueueAndExecute.s.sol --sig "executeProposal()" --rpc-url $RPC_URL --broadcast
```

#### 5. Utility Functions

```bash
# Check DAO status
forge script script/InteractWithDAO.s.sol --rpc-url $RPC_URL

# Check user voting power
forge script script/InteractWithDAO.s.sol --sig "checkUserStatus(address)" 0xYourAddress --rpc-url $RPC_URL
```

## Configuration

### Governor Settings (src/MyGovernor.sol)

```solidity
GovernorSettings(
    7200,  // Voting delay (1 day)
    50400, // Voting period (1 week)  
    0      // Proposal threshold (0 tokens)
)
```

### Timelock Settings (script/DeployDAO.s.sol)

```solidity
uint256 public constant MIN_DELAY = 3600; // 1 hour
```

### Token Settings (script/DeployDAO.s.sol)

```solidity
uint256 public constant INITIAL_SUPPLY = 1000000 ether; // 1M tokens
```

## Security Features

- **Timelock Protection**: 1-hour delay prevents immediate execution
- **Role-Based Access**: Only governor can propose/execute
- **Voting Requirements**: Quorum and majority thresholds
- **Delegation Required**: Users must delegate tokens to vote
- **Comprehensive Testing**: Edge cases and attack vectors covered

## Important Notes

### OpenZeppelin v5 Compatibility

This project uses OpenZeppelin Contracts v5, which has breaking changes:

- `Ownable` constructor requires `initialOwner` parameter
- `TimelockController` uses `DEFAULT_ADMIN_ROLE` instead of `TIMELOCK_ADMIN_ROLE`

### Production Considerations

1. **Token Distribution**: The mint function allows anyone to mint tokens - implement proper access control for production
2. **Governance Parameters**: Consider your specific use case for voting delays and periods
3. **Admin Roles**: Carefully manage timelock admin roles for decentralization
4. **Upgradeability**: Current implementation is not upgradeable

**Important**: This uses ERC20 token-based voting, which can lead to plutocracy (rule by the wealthy). This is for educational purposes only. Consider alternative governance mechanisms like quadratic voting, reputation-based systems, or delegation models for production use.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass and coverage remains high
5. Submit a pull request

## Learning Resources

- [Cyfrin Advanced Foundry Course](https://updraft.cyfrin.io/) - The course this project is based on
- [Patrick Collins YouTube Channel](https://www.youtube.com/c/PatrickCollins) - Excellent blockchain development tutorials
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/api/governance)
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## Disclaimer

This code is for educational purposes. Audit thoroughly before using in production. DAOs involve complex governance mechanisms and should be carefully designed for your specific use case.

## License

MIT License - see LICENSE file for details.

---

Built with love during the Cyfrin Advanced Foundry Course. Thanks again to Patrick Collins and the entire Cyfrin team for making blockchain education accessible and fun!