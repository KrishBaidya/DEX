# DEX - Decentralized Exchange

## Overview

DEX is a decentralized exchange (DEX) protocol built on Ethereum, allowing users to trade tokens, add liquidity, and swap between tokens with an intermediary (ETH). It features tax rates, custom staking pools, and pausable functionality for added security and flexibility.

This project includes the following smart contracts:
- **ExchangeRouter**: Manages the creation and interaction with multiple DEX pools.
- **DEX**: Handles liquidity pools, pricing, and token swaps.
- **Pool**: Manages staking and liquidity for tokens with configurable tax rates.
- **MEME**: An ERC-20 token used for testing.

## Features

- **Token Swapping**: Swap between different tokens with ETH as an intermediary.
- **Liquidity Provision**: Add liquidity for tokens to enable swaps.
- **Taxable Pools**: Custom pools with different tax rates on transactions.
- **Staking**: Earn rewards by staking tokens in pools.
- **Pausing Functions**: The owner can pause/unpause trading to manage risks.
- **Ownable**: Only the owner can perform certain operations like minting tokens, pausing exchanges, or managing liquidity.

## Contracts

- **ExchangeRouter.sol**: This contract is responsible for creating new DEX instances for tokens and managing the interaction between users and the DEX pools.
- **DEX.sol**: Manages token swaps and liquidity for each token.
- **Pool.sol**: Handles staking and liquidity for tokens, with a configurable tax rate.
- **Meme.sol**: A sample ERC20 Token.

## Setup

### Requirements

- Node.js & npm
- Hardhat
- Solidity 0.8.27

### Installation

1. Clone the repository:

```bash
git clone https://github.com/KrishBaidya/DEX.git
cd DEX
```
Install dependencies:
```bash
npm install
```
Compile the contracts:
``` bash
npx hardhat compile
```
Run tests:
``` bash
npx hardhat test
```
### Testing
This repository includes tests written in JavaScript using Hardhat and Chai. To run the tests, execute:

``` bash
npx hardhat test
```

**Note** - Note: Some of the tests may fail or require updates, and some are currently commented out with TODOs for future updates.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

Contributing
Contributions, issues, and feature requests are welcome! Feel free to check out the issues page.