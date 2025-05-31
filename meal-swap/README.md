# Meal Swap Platform

A Clarity-based smart-contract project on the Stacks blockchain, enabling peer-to-peer meal-for-meal exchanges.

## Project Structure

```
meal-swap-platform/
├── .gitignore
├── README.md
├── Clarinet.toml
├── contracts/
│   └── meal-swap.clar
└── src/
    └── main.ts
```

## Prerequisites

- Rust toolchain (for Clarinet to compile Clarity contracts).
- Clarinet CLI (`npm install -g @hirosystems/clarinet`).
- Node.js and npm (for TypeScript-based tests).

## Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd meal-swap-platform
   ```

2. **Install dependencies** (for TypeScript tests, if applicable):
   ```bash
   npm install
   ```

3. **Compile the contract**:
   ```bash
   clarinet compile
   ```

4. **Run a local node** (for development & testing):
   ```bash
   clarinet node
   ```

5. **Run tests**:
   ```bash
   clarinet test
   ```

## Contract Details

- **Contract name**: `meal-swap`
- **Purpose**: List meals, propose swaps, accept or cancel swaps.
- **Key maps**:
  - `meals`: stores `meal-id` → `{ owner, description, available }`
  - `swap-requests`: stores `swap-id` → `{ proposer, proposee, meal-offered, meal-requested, accepted }`
