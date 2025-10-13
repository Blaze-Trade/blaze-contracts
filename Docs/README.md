# Blaze Contracts Docs

This folder contains documentation for the Blaze contracts.

- `launchpad.md`: Detailed documentation for the `blaze_token_launchpad::launchpad` Move module.

## Project Overview

This repository defines a launchpad for creating and trading fungible assets (FAs) on Aptos. It supports:

- Creation of standard FAs with optional per-unit mint fee and per-address mint limits.
- Creation of bonding-curve FAs whose buy/sell price is determined by a polynomial curve (currently quadratic), with APT liquidity tracked via a resource account.

## Repository Layout

- `move/sources/launchpad.move`: Core Move module `blaze_token_launchpad::launchpad`.
- `Docs/`: Documentation.

## Quick Start

- Ensure Aptos CLI and Move toolchain are installed.
- To run tests:
  - From repo root: `aptos move test`

## Key Concepts

- Sticky Objects and Primary Fungible Store: FAs are created as objects; user balances live in the primary fungible store.
- Bonding Curve (quadratic): Price and cost/payout are functions of the total supply and a virtual liquidity parameter; buys deposit APT to a resource account, sells pay out from it if liquidity is available.

See `Docs/launchpad.md` for full details.
