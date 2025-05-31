# Meal Swap Platform (Phase 2)

A decentralized meal swap platform built on Stacks blockchain using Clarity smart contracts. Users can propose meal swaps, match with others, and build reputation through successful exchanges.

## 🚀 New Features in Phase 2

### 🔒 Security Enhancements
- **Input validation** for all user inputs
- **Rate limiting** to prevent spam (max 5 proposals per user with cooldown)
- **Access controls** with owner-only functions
- **Overflow protection** for all arithmetic operations
- **Authorization checks** for all state-modifying operations

### 🆕 Enhanced Functionality
- **Proposal status management** (Active, Matched, Completed, Cancelled)
- **Matching system** to connect compatible proposals
- **Swap completion** workflow requiring both parties' confirmation
- **Proposal cancellation** by owner or contract admin
- **Bulk proposal queries** with pagination
- **User activity tracking** and limits

### 🏆 Reputation System
- New **reputation-system.clar** contract
- **User ratings** (1-5 stars) with comments
- **Trust scores** combining ratings and swap history
- **Rating validation** to prevent abuse
- **Integration** with main meal-swap contract

### 🛠️ Technical Improvements
- **Enhanced data structures** with more fields
- **Better error handling** with specific error codes
- **Gas optimization** through efficient queries
- **Contract integration** patterns
- **Comprehensive testing** setup

## 📋 Requirements

- [Clarinet](https://github.com/hirosystems/clarinet) v1.5.0+
- [Stacks CLI](https://github.com/blockstack/stacks-blockchain/tree/master/src/stacks-cli) v0.1.0+
- Node.js v16+ (for development scripts)

## 🏗️ Installation

```bash
# Clone the repository
git clone <repository-url>
cd meal-swap-platform

# Install Clarinet (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://install.clarinet.sh | sh

# Verify installation
clarinet --version
```

## 🚀 Quick Start

### 1. Start Development Environment

```bash
# Start local blockchain
clarinet integrate

# In another terminal, start the console
clarinet console
```

### 2. Deploy Contracts

```bash
# Deploy both contracts
clarinet deploy --testnet

# Or deploy locally for development
clarinet check
```

### 3. Interact with Contracts

```clarity
;; Create a meal proposal
(contract-call? .meal-swap create-proposal 
  "Homemade pasta with fresh tomato sauce" 
  "Asian stir-fry or curry dishes")

;; Check the proposal
(contract-call? .meal-swap get-proposal u1)

;; Match two proposals
(contract-call? .meal-swap match-proposals u1 u2)

;; Rate a user after completing a swap
(contract-call? .reputation-system rate-user 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  u5 
  "Great meal, exactly as described!"
  u1)
```

## 📖 Contract Documentation

### Meal Swap Contract (`meal-swap.clar`)

#### Key Functions

| Function | Type | Description |
|----------|------|-------------|
| `create-proposal` | Public | Create a new meal swap proposal |
| `match-proposals` | Public | Match two compatible proposals |
| `complete-swap` | Public | Mark a matched swap as completed |
| `cancel-proposal` | Public | Cancel an active proposal |
| `get-proposal` | Read-only | Get proposal details by ID |
| `get-match` | Read-only | Get match details by ID |
| `get-active-proposals-range` | Read-only | Get paginated active proposals |

#### Data Structures

```clarity
;; Proposal Structure
{ proposer: principal
  meal-details: (string-ascii 128)
  desired-meal: (string-ascii 128)
  status: uint
  created-at: uint
  matched-with: (optional uint)
  matcher: (optional principal) }

;; Match Structure
{ proposal-a: uint
  proposal-b: uint
  proposer-a: principal
  proposer-b: principal
  created-at: uint
  completed: bool }
```

### Reputation System Contract (`reputation-system.clar`)

#### Key Functions

| Function | Type | Description |
|----------|------|-------------|
| `rate-user` | Public | Submit a rating for a completed swap |
| `increment-user-swap-count` | Public | Increment user's swap counter (contract only) |
| `get-user-reputation` | Read-only | Get user's reputation data |
| `get-user-trust-score` | Read-only | Get calculated trust score |
| `has-rated-match` | Read-only | Check if user has rated a match |

#### Data Structures

```clarity
;; Reputation Structure
{ total-rating: uint
  rating-count: uint
  average-rating: uint
  total-swaps: uint }

;; Rating Structure
{ rater: principal
  rated-user: principal
  rating: uint
  comment: (string-ascii 256)
  match-id: uint
  created-at: uint }
```

## 🔧 Status Codes

### Meal Swap Contract
- `u100` - ERR-NOT-FOUND: Resource not found
- `u101` - ERR-UNAUTHORIZED: Action not authorized
- `u102` - ERR-INVALID-INPUT: Invalid input provided
- `u103` - ERR-PROPOSAL-NOT-ACTIVE: Proposal is not in active state
- `u104` - ERR-CANNOT-MATCH-OWN-PROPOSAL: Cannot match your own proposal
- `u105` - ERR-ALREADY-MATCHED: Already matched or completed
- `u106` - ERR-SWAP-NOT-READY: Swap not ready for completion

### Reputation System Contract
- `u200` - ERR-NOT-FOUND: Resource not found
- `u201` - ERR-UNAUTHORIZED: Action not authorized
- `u202` - ERR-ALREADY-RATED: Match already rated by user
- `u203` - ERR-INVALID-RATING: Invalid rating value or comment
- `u204` - ERR-CANNOT-RATE-SELF: Cannot rate yourself
- `u205` - ERR-SWAP-NOT-COMPLETED: Swap not completed yet

## 🧪 Testing

### Running Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/meal-swap_test.ts

# Run with coverage
clarinet test --coverage
```

### Test Coverage

The test suite covers:
- ✅ Proposal creation and validation
- ✅ Proposal matching workflow
- ✅ Swap completion process
- ✅ Access control and security
- ✅ Rate limiting functionality
- ✅ Reputation system integration
- ✅ Error handling scenarios
- ✅ Edge cases and overflow protection

### Sample Test Cases

```typescript
// Example test structure
describe("Meal Swap Contract", () => {
  it("should create a proposal with valid input", () => {
    // Test implementation
  });
  
  it("should reject invalid meal descriptions", () => {
    // Test implementation
  });
  
  it("should enforce rate limiting", () => {
    // Test implementation
  });
});
```

## 🔒 Security Considerations

### Implemented Protections

1. **Input Validation**
   - String length limits (1-128 characters)
   - Non-empty string requirements
   - Rating bounds validation (1-5)

2. **Access Controls**
   - Owner-only functions for admin operations
   - Participant-only functions for matches
   - Self-rating prevention

3. **Rate Limiting**
   - Maximum 5 proposals per user
   - Block-height based cooldown
   - Spam prevention mechanisms

4. **Integer Overflow Protection**
   - Safe arithmetic operations
   - Maximum value checks
   - Proper error handling

5. **State Consistency**
   - Atomic operations
   - Status validation
   - Referential integrity

### Security Best Practices

- Always validate inputs before processing
- Use `asserts!` for critical validations
- Implement proper access controls
- Handle all error cases explicitly
- Test extensively with edge cases
- Monitor for unusual activity patterns

## 🚀 Deployment

### Local Development

```bash
# Deploy to local devnet
clarinet integrate --epoch 2.5

# Deploy contracts
clarinet deployment apply --devnet
```

### Testnet Deployment

```bash
# Generate deployment plan
clarinet deployment generate --testnet

# Deploy to testnet
clarinet deployment apply --testnet
```

### Mainnet Deployment

⚠️ **Warning**: Thoroughly test on testnet before mainnet deployment

```bash
# Final testing
clarinet test --coverage

# Generate mainnet deployment
clarinet deployment generate --mainnet

# Deploy to mainnet (requires sufficient STX)
clarinet deployment apply --mainnet
```

## 📊 Usage Examples

### Creating and Matching Proposals

```clarity
;; User A creates a proposal
(contract-call? .meal-swap create-proposal 
  "Homemade pizza with fresh mozzarella" 
  "Thai green curry or pad thai")

;; User B creates a complementary proposal
(contract-call? .meal-swap create-proposal 
  "Authentic Thai green curry with jasmine rice" 
  "Italian dishes or homemade pasta")

;; User A matches the proposals
(contract-call? .meal-swap match-proposals u1 u2)

;; Both users complete the swap
(contract-call? .meal-swap complete-swap u1)
```

### Building Reputation

```clarity
;; After successful swap, rate the other user
(contract-call? .reputation-system rate-user 
  'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
  u5 
  "Amazing curry! Perfect spice level and authentic taste."
  u1)

;; Check user's reputation
(contract-call? .reputation-system get-user-reputation 
  'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)

;; Get trust score
(contract-call? .reputation-system get-user-trust-score 
  'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
```

## ��️ Roadmap

### Phase 3 (Planned)
- [ ] Advanced matching algorithms
- [ ] Geographic location integration
- [ ] Token incentives for participation
- [ ] Mobile app integration
- [ ] Community governance features

### Phase 4 (Future)
- [ ] Cross-chain compatibility
- [ ] AI-powered meal recommendations
- [ ] Subscription meal plans
- [ ] Restaurant partnership integration
- [ ] NFT meal certificates

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Style

- Follow Clarity best practices
- Use descriptive variable names
- Add comprehensive comments
- Include error handling
- Write tests for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- **Documentation**: Check this README and inline code comments
- **Issues**: Open a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Discord**: Join our community Discord server

## 🏆 Acknowledgments

- Stacks Foundation for the blockchain platform
- Clarity language documentation and community
- Open source contributors and testers
- Early adopters and feedback providers

