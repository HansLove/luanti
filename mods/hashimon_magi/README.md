# hashimon_magi — the MAGI as a physical object

A MAGI is a finite cubic object that sits in a player's inventory, can be placed in
the world as a block, dropped, handed to another player, or put back into a vault.
It is a **bearer object**: whoever holds the item holds the MAGI. What it is *not*
is self-authenticating — the item carries a claim, and `api/src/domain/magi.ts`
holds the ledger that decides whether the claim is true.

This is the physical-note model (Luanti's equivalent of NBT-tagged bank notes) rather
than a Vault-style intangible balance: the object is the point. The vault exists only
as the dematerialized form you can hold when you don't want to carry cubes.

## Why a seal is not enough

The usual design stops at "print a cryptographic hash into the item metadata and
check it against a database at redemption". That catches **forgery** — a fabricated
note, or one whose denomination was edited — because the HMAC seal is computed with
a secret the client never has.

It does not catch **duplication**. A duped item is byte-identical to the original,
so its seal is perfectly valid. Checking only at redemption means both copies spend
successfully until someone notices, and by then supply has already moved.

So every MAGI also carries a **custody nonce**, and the ledger rotates it on every
custody check:

```
issue     note.nonce = n0                         ledger.nonce = n0
check     presents n0  -> ok, rewritten with n1   ledger.nonce = n1
dupe                                              (two items, both carrying n1)
check A   presents n1  -> ok, rewritten with n2   ledger.nonce = n2
check B   presents n1  -> STALE, item destroyed   ledger.nonce = n2
```

Custody becomes a chain, and a duplicate is a fork in it. The moment either copy is
checked, the other is presenting a nonce the ledger has already retired. **A dupe
glitch therefore leaves exactly one surviving MAGI, never two** — which is the
property that actually matters: the server never has to work out which copy was the
"original", because supply is preserved either way.

Checks run on join, on pickup, on placement, on `/magi verify`, on deposit, and on a
timer (`hashimon_magi.sweep_interval`, default 180s — the timer's job is duplication
*latency*, so a clone that never changes hands still gets caught).

**A failure to reach the ledger is never a verdict.** Only `stale`, `forged`,
`unknown` and `retired` destroy an item. A timeout, a 503 or a missing secret leaves
the note untouched and marked unverified — an API outage must not confiscate money.

## Setup

Server side (`api/`):

```bash
# .env
MAGI_SEAL_SECRET=<long random string>   # without it the /magi routes answer 503
MAGI_SUPPLY_CAP=21000
MAGI_SATS_PER_MAGI=1000
MAGI_EPOCH=1
LUANTI_SERVER_SECRET=<same value as the world's hashimon_server_secret>
```

```bash
pnpm build && pnpm migrate   # creates magi_notes + magi_custody_log
pnpm dev
```

World side (`minetest.conf`) — the mod depends on `hashimon_core` and borrows its
HTTP handle, so only `hashimon_core` goes in `secure.http_mods`:

```
secure.http_mods = hashimon_core
hashimon_api_url = http://127.0.0.1:4000
hashimon_server_secret = <same value as LUANTI_SERVER_SECRET>
hashimon_magi.sweep_interval = 180
```

## Commands

| Command | What it does |
|---|---|
| `/magi` / `/magi status` | vault balance, notes materialized under your name, notes in hand |
| `/magi withdraw <n>` | vault → inventory (one slot per note; a MAGI never stacks) |
| `/magi deposit <n\|all>` | inventory → vault; a note that fails custody is destroyed, not deposited |
| `/magi verify` | force a custody check on everything you carry |
| `/magi supply` | issued vs. cap, and the sats the issued supply claims as backing |
| `/magi mint <player> <n>` | issue new MAGI into a vault — needs `magi_admin`, refused past the cap |

Right-clicking in the air with a MAGI in hand inspects that single note. (Not left
click: an `on_use` handler would stop the item digging and get in the way of
punching creatures.)

## Reproducing the duplication defence

```
/grantme magi_admin
/magi mint <you> 2
/magi withdraw 2
/magi verify                  -- 2 verified and re-sealed
```

Then simulate a dupe glitch, which is the only way to get two items with one serial:

```
/lua local p = minetest.get_player_by_name("<you>")
     local inv = p:get_inventory()
     inv:add_item("main", inv:get_stack("main", 1))   -- byte-identical copy
/magi verify
```

The first copy verifies and rotates; the second is destroyed with
`its custody nonce was already retired`. One MAGI survives, and
`/magi supply` is unchanged. `magi_custody_log` holds the rejected event with the
presented nonce and the ledger's sequence number.

## HTTP surface

`GET /magi/supply` is public — the supply of a finite object should be inspectable
by anyone. Everything else is under `/internal/magi/*` behind `X-Luanti-Secret`
(`issue`, `withdraw`, `deposit`, `custody`, `holder/:name`), because the world is a
trusted caller acting on behalf of the player it names.

## Not built here

- **Transfer is physical only.** Handing over the item is the transfer; there is no
  `/magi pay <player>`, and no signature chain binding a note to an owner's key.
  That belongs with the ownership work in `docs/OWNERSHIP_AND_TRANSFER.md`.
- **The reserve is asserted, not proven.** `reserveSats` is derived from the ledger
  (`issued × MAGI_SATS_PER_MAGI`). Publishing a CLTV-locked reserve and verifying it
  on chain is the Magi protocol's own scope, not this mod's.
- **Epoch rollover.** `MAGI_EPOCH` is stamped into every seal, but there is no
  re-sealing pass for notes issued under a previous epoch.
- **NPC and institutional holders.** Holders are Luanti account names only.
