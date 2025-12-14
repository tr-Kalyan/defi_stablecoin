# Decentralized Stable Coin (DSC) Protocol

A minimal, overcollateralized stablecoin system built as part of the Cyfrin Foundry DeFi course.

The protocol allows users to deposit WETH and/or WBTC as collateral and mint DSC tokens against it, maintaining a target 200% collateralization ratio (configurable via constants). DSC is intended to be pegged 1:1 to USD through overcollateralization and liquidation incentives.

This implementation follows the architectural patterns seen in systems like MakerDAO's DAI, but simplified: no governance, no stability fees, and only two collateral types.

## Architecture Overview

- **DecentralizedStableCoin.sol** – ERC20 token owned by the engine; minting and burning restricted to the DSCEngine.
- **DSCEngine.sol** – Core protocol logic:
  - Deposit/withdraw collateral
  - Mint/burn DSC
  - Health factor calculation
  - Partial liquidation with 10% liquidator bonus
- **OracleLib.sol** – Lightweight library that reverts on stale or non-positive Chainlink prices (circuit-breaker behavior).
- **HelperConfig & DeployDSC** – Chain-aware configuration and deployment scripts for local/Anvil and Sepolia.

## Key Design Decisions

- **Overcollateralization enforced via post-action health factor checks** – state is optimistically updated, then validated; reverts roll back changes.
- **Oracle failure → protocol freeze** – deliberate choice to prioritize safety over availability.
- **Liquidation incentive** – 10% bonus to encourage rapid correction of undercollateralized positions.
- **Minimalism** – no fees, no governance, no complex math beyond basic ratio checks.

## Testing Approach

- **Unit tests** – Cover happy paths, known edge cases, and custom error conditions (96%+ line/statement coverage on DSCEngine).
- **Adversarial mocks** – Tokens that return false on transfer/transferFrom or fail mint to test TransferFailed/MintFailed paths.
- **Invariant / fuzz testing** – Bounded handler simulating realistic user and liquidator actions (deposit, mint, redeem, burn, liquidate, bounded price updates).
  - Primary invariant: total USD value of collateral ≥ total DSC supply (allowing temporary undercollateralization if liquidation is possible).
  - Secondary: critical view functions never revert.

No violations of the core overcollateralization invariant were found under realistic conditions.

## Limitations & Known Behaviors

- Temporary undercollateralization can occur after sharp price drops until a liquidator acts.
- Extreme or negative price inputs are rejected by OracleLib (protocol freezes).
- Liquidator must hold DSC to cover debt (real-world liquidators often use flash loans, not modeled here).

## 👨‍💻 Author

**Kalyan TR**

> Former regulated-domain QA (Finance + Healthcare) → transitioning to Web3 Security
Active on CodeHawks & Code4rena


[![GitHub](https://img.shields.io/badge/GitHub-tr--Kalyan-black?style=for-the-badge&logo=github)](https://github.com/tr-Kalyan)

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.