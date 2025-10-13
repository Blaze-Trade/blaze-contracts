# blaze_token_launchpad::launchpad

Detailed documentation for the `move/sources/launchpad.move` module.

## Overview

Provides a launchpad to:

- Create standard fungible assets (FAs) with optional per-unit mint fee and per-address mint limits.
- Create FAs with a bonding curve market (quadratic by default) where price depends on token supply and a virtual liquidity parameter.
- Manage collected APT in a contract-controlled resource account for buy/sell flows.

The module relies on Aptos' `fungible_asset` and `primary_fungible_store` for supply and balances, and `object` for FA objects.

## Key Resources and Structs

- `Registry has key`
  - `fa_objects: vector<Object<Metadata>>`
  - Global list of created FA objects.

- `Config has key`
  - `admin_addr: address`
  - `pending_admin_addr: Option<address>`
  - `mint_fee_collector_addr: address`

- `FAController has key`
  - Holds per-FA capabilities: `mint_ref`, `burn_ref`, `transfer_ref`.

- `MintLimit has store`
  - `limit: u64`
  - `mint_tracker: Table<address, u64>` (per-address lifetime minted amount)

- `FAConfig has key`
  - `mint_fee_per_smallest_unit_of_fa: u64`
  - `mint_limit: Option<MintLimit>`

- `BondingCurve has key, copy, drop`
  - `target_supply: u64`
  - `virtual_liquidity: u64`
  - `curve_exponent: u64` (stored, logic assumes 2)
  - `is_active: bool`

- `LiquidityPool has key`
  - `total_apt_collected: u64`
  - `total_apt_paid_out: u64`

- `ResourceAccountCapability has key`
  - `signer_capability: SignerCapability` for the resource account that holds APT liquidity.

## Events

- `CreateFAEvent`
- `MintFAEvent`
- `CreateBondingCurveFAEvent`
- `BondingCurveMintEvent`
- `BondingCurveTargetReachedEvent`
- `BondingCurveSellEvent`

## Initialization

- `init_module(sender: &signer)`
  - Stores `Registry`, `Config` (admin = `sender`), `LiquidityPool` under the module address.
  - Creates a resource account with seed `"liquidity_pool"` and stores its capability in `ResourceAccountCapability`.

## Entry Functions

- `set_pending_admin(sender, new_admin)` acquires `Config`
  - Only admin (or object owner if published under object) can set.

- `accept_admin(sender)` acquires `Config`
  - Only current `pending_admin` can call. Promotes to `admin`.

- `update_mint_fee_collector(sender, new_addr)` acquires `Config`
  - Admin-only. Sets recipient of fixed mint fees (non-bonding-curve FA).

- `create_fa(sender, ..., mint_fee_per_smallest_unit_of_fa: Option<u64>, pre_mint_amount: Option<u64>, mint_limit_per_addr: Option<u64>)` acquires `Registry, FAController`
  - Creates a sticky FA object and stores `FAController` and `FAConfig` under the FA address.
  - Registers in `Registry` and emits `CreateFAEvent`.
  - If `pre_mint_amount > 0`: mints to `sender` without fee.

- `mint_fa(sender, fa_obj, amount)` acquires `FAController, FAConfig, Config`
  - Enforces mint limit if configured. Computes fee `amount * mint_fee_per_unit` and transfers APT to `mint_fee_collector_addr`. Mints to `sender`.

- `create_token(sender, ..., target_supply, virtual_liquidity, curve_exponent, mint_limit_per_addr)` acquires `Registry`
  - Creates FA with `FAController`, `FAConfig` (fixed fee = 0), and `BondingCurve { is_active: true }`.
  - Emits `CreateBondingCurveFAEvent`.

- `buy_token(sender, fa_obj, amount)` acquires `FAController, FAConfig, BondingCurve, LiquidityPool, ResourceAccountCapability`
  - Requires bonding curve active. Enforces mint limit. Computes `total_cost` from bonding curve and transfers APT to the resource account, updating `LiquidityPool.total_apt_collected`. Mints tokens to `sender`. Deactivates curve if `target_supply` reached. Emits `BondingCurveMintEvent`.

- `sell_token(sender, fa_obj, amount)` acquires `FAController, BondingCurve, LiquidityPool, ResourceAccountCapability`
  - Requires curve active and user's FA balance ≥ amount. Computes `payout` from bonding curve. Burns user tokens. Pays out from the resource account if `get_available_liquidity() ≥ payout`, updating `LiquidityPool.total_apt_paid_out`. Emits `BondingCurveSellEvent`.

## View Functions

- Admin/addresses: `get_admin()`, `get_pending_admin()`, `get_mint_fee_collector()`.
- Registry: `get_registry()`.
- FA metadata: `get_fa_object_metadata(fa_obj)`.
- Mint limits: `get_mint_limit(fa_obj)`, `get_current_minted_amount(fa_obj, addr)`.
- Fees: `get_mint_fee(fa_obj, amount)`.
- Bonding curve: `get_bonding_curve(fa_obj)`, `get_bonding_curve_price(fa_obj, amount)`, `get_bonding_curve_mint_cost(fa_obj, amount)`, `get_bonding_curve_sell_payout(fa_obj, amount)`.
- Liquidity: `get_liquidity_pool()`, `get_available_liquidity()`.
- Resource account: `get_resource_account_address()`.

## Helper Functions

- `is_admin(config, sender_addr)`
  - True if `sender_addr == admin_addr`; if module published under an object, also true for the object owner.

- `check_mint_limit_and_update_mint_tracker(sender_addr, fa_obj, amount)`
  - Enforces `old + amount <= limit` and updates mint tracker if `mint_limit` exists.

- `mint_fa_internal(sender, fa_obj, amount, total_mint_fee)`
  - Mints and emits `MintFAEvent`.

- `pay_for_mint(sender, total_mint_fee)`
  - Transfers APT to `mint_fee_collector_addr` if `total_mint_fee > 0`.

## Bonding Curve Math (Quadratic)

Let `supply = current total supply (u128, downcasted to u64 when used)` and `VL = virtual_liquidity`.

- Price estimate for amount `amt`:
  - `price ≈ (supply^2 * amt) / VL`
- Mint cost for buying `amt`:
  - `cost = ((supply + amt)^3 - supply^3) / (3 * VL)`
- Sell payout for selling `amt`:
  - `payout = (supply^3 - (supply - amt)^3) / (3 * VL)` (only if `supply ≥ amt`)

Notes:
- Uses `u64` arithmetic; consider overflow constraints for large supplies.
- `curve_exponent` is stored but the implementation assumes exponent 2.

## Access Control

- Admin-only:
  - `set_pending_admin`, `accept_admin` (pending admin), `update_mint_fee_collector`.
- Public mint/buy/sell are guarded by mint limits, balances, curve activity, and liquidity checks.

## Liquidity and Resource Account

- A resource account is created at `init_module` and its capability stored in `ResourceAccountCapability`.
- `buy_token` transfers APT from users to the resource account and increments `total_apt_collected`.
- `sell_token` pays out from the resource account if `get_available_liquidity() = collected - paid_out` is sufficient.

## Errors

- `EONLY_ADMIN_CAN_UPDATE_CREATOR = 1`
- `EONLY_ADMIN_CAN_SET_PENDING_ADMIN = 2`
- `ENOT_PENDING_ADMIN = 3`
- `EONLY_ADMIN_CAN_UPDATE_MINT_FEE_COLLECTOR = 4`
- `ENO_MINT_LIMIT = 5`
- `EMINT_LIMIT_REACHED = 6`
- `ERESOURCE_ACCOUNT_NOT_INITIALIZED = 7`
- `EINSUFFICIENT_LIQUIDITY = 8`

## Developer Notes and Recommendations

- Consider guarding against `u64` overflows in bonding-curve math; use `u128` intermediate math where appropriate.
- Either enforce `curve_exponent == 2` or implement generalized exponent handling.
- Confirm intended semantics that selling does not reduce mint tracker (i.e., tracker is lifetime minted, not net minted).
- Optional admin functions (not present): liquidity top-up/withdraw with events and access control.
- If desired, add explicit `max_supply` enforcement in `buy_token` path (framework may enforce, but making it explicit can improve clarity).

## Example Flows

### Create a standard FA and mint
1. Call `init_module` once.
2. `create_fa(..., mint_fee_per_unit = some(u64), pre_mint = none(), mint_limit = some(limit))`.
3. `mint_fa(fa_obj, amount)` transfers fee to `mint_fee_collector` and mints to caller.

### Create a bonding-curve FA, buy and sell
1. Call `init_module` once (creates resource account).
2. `create_token(..., target_supply, virtual_liquidity, curve_exponent = 2, mint_limit = some(limit))`.
3. `buy_token(fa_obj, amount)` computes cost and transfers APT to the resource account, then mints to caller.
4. `sell_token(fa_obj, amount)` burns tokens and pays APT from resource account if liquidity is sufficient.

## Tests

Run all tests with:

```bash
aptos move test
```

Tests cover creation, minting, bonding-curve pricing, target deactivation, mint-limit enforcement, and liquidity accounting (`move/sources/launchpad.move`).
