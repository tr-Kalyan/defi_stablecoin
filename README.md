# Algorithmic Solvency Engine (DSCEngine)

![Foundry](https://img.shields.io/badge/Built%20With-Foundry-orange)
![License](https://img.shields.io/badge/License-MIT-blue)
![Coverage](https://img.shields.io/badge/Coverage-96%25-green)
![Fuzzing](https://img.shields.io/badge/Fuzzing-1000%2B%20Runs-purple)

## ⚡ Executive Summary
A decentralized, over-collateralized stablecoin system implementing the MakerDAO DSS (Dai Stablecoin System) architectural pattern. The protocol maintains a **1:1 USD peg** via algorithmic liquidation incentives and rigid collateralization thresholds (200%).

Unlike governance-heavy implementations, this protocol utilizes an **immutable, governance-free architecture** to minimize the attack surface and eliminate centralization risks.

> **⚠️ ARCHITECTURAL NOTE:**
> This implementation utilizes a **Single-Oracle design** (Chainlink) with `OracleLib` staleness checks for efficiency. For Mainnet production, a **Dual-Oracle** (Chainlink + Pyth/Uniswap TWAP) fallback pattern is recommended to prevent DoS during single-oracle outages.

---

## 🛡️ Security & Invariant Analysis
*Date: December 14, 2025*

This protocol has undergone extensive **Stateful Fuzz Testing** to verify economic solvency under adversarial conditions.

### Core Invariant
> The protocol must maintain overcollateralization **OR** ensure that any underwater position is immediately liquidatable.

### Fuzzing Campaign Metrics
| Metric | Value | Description |
|:--- |:--- |:--- |
| **Handler** | Stateful | Multi-user simulations (Deposit, Mint, Redeem, Burn, Liquidate) |
| **Price Volatility** | $100 - $100k | Randomized Chainlink feed updates to stress-test health factors |
| **Iterations** | > 1,000 | Deep-state sequences to find edge-case insolvency |

### Validated Security Properties
1.  **Solvency Guarantee:** No violations of the core invariant were found when the liquidation engine is active.
2.  **Oracle Security:** `OracleLib` successfully reverts on stale (>3 hours) or non-positive price data, preventing "Bad Data" insolvency.
3.  **Math Safety:** No overflow/underflow vulnerabilities detected in the `WadRayMath` debt calculation logic.
4.  **Access Control:** No unauthorized minting or collateral extraction was possible during random seed runs.

---

## 🏗️ System Architecture

### Smart Contracts
* **`DSCEngine.sol` (Core Logic):**
    * Handles all collateral deposits and redemptions.
    * Enforces the `HealthFactor` checks ($HF < 1.0$ triggers liquidation).
    * Implements the "Pull over Push" payment pattern to prevent reentrancy.
* **`DecentralizedStableCoin.sol` (ERC-20):**
    * Owned exclusively by the Engine.
    * Burn/Mint logic restricted to solvency-checked transactions.
* **`OracleLib.sol` (Circuit Breaker):**
    * Wraps Chainlink Aggregators to enforce heartbeat validity.
    * Reverts transactions if price feeds are stale, freezing the protocol to protect funds.

### Risk Parameters
* **Liquidation Threshold:** 50% (200% Over-collateralization required).
* **Liquidation Bonus:** 10% (Incentivizes keepers to restore system health).
* **Precision:** 1e18 (Standardized to prevent dust-loss during swaps).

---

## 🧪 Testing Strategy
The codebase employs a tiered testing approach focusing on **Correctness** and **Economic Safety**.

1.  **Unit Tests:** 96%+ Line coverage on `DSCEngine.sol`. Covers happy paths, Revert strings, and Access Control.
2.  **Adversarial Mocks:** Custom ERC-20 mocks that return `false` on transfers or fail minting to verify `SafeERC20` wrapper logic and error handling.
3.  **Invariant Handlers:**
    * **Solvency:** `totalCollateralValue >= totalSupply`
    * **Getter Safety:** Critical view functions never revert (DoS protection).

---

## 👨‍💻 Author

**Kalyan TR**
*Smart Contract Security Researcher & SDET*

> Transitioning 5 years of regulated-domain QA (Finance/Healthcare) into Web3 Security.
> Active contributor to OpenZeppelin and competitor on CodeHawks/Sherlock.

[![GitHub](https://img.shields.io/badge/GitHub-tr--Kalyan-black?style=for-the-badge&logo=github)](https://github.com/tr-Kalyan)