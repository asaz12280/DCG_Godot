# ADR 20260710: Stash Currency Account

## Status

Accepted

## Context

The warehouse needs a deposit and withdrawal flow without changing the meaning
of player wallet money used by upgrades, repairs, rewards, and vendors.

## Decision

Persist warehouse coins as `stash_money`, separate from `money`.
`StashCurrencyService` owns amount-bounded deposit and withdrawal. The
warehouse UI owns only the temporary amount slider, confirmation, and cancel
state before it requests a service action.

## Options Considered

- Reuse `money`: rejected because stored coins would remain spendable by base systems.
- Add a currency ItemDef stack: rejected because the current wallet and reward flow already uses saved money.
- Add `stash_money`: chosen because it is explicit, persistent, and isolated.

## Consequences

- Positive: stored coins cannot be spent until withdrawn.
- Positive: legacy saves safely receive `stash_money = 0`.
- Tradeoff: the first version uses a slider for partial amounts; keyboard amount entry can be added later without changing the service contract.

## Validation

- `res://tools/validate_base_stash_storage_ui.gd`
- `res://tools/validate_save_slots.gd`

## Links

- `res://scripts/base/stash_currency_service.gd`
- `res://scripts/save/save_game_manager.gd`
- `res://scripts/ui/base_stash_inventory_ui.gd`
