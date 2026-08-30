-- MAGI: a finite cubic object that lives in a player's inventory.
--
-- The item is a bearer object — whoever holds it holds the MAGI — but the item is
-- not the authority on its own validity. Each note carries a serial, its sats
-- backing, an epoch and a *custody nonce*, all covered by an HMAC seal the server
-- alone can produce. The ledger (api/src/domain/magi.ts) decides:
--
--   * a fabricated or edited note fails its seal          -> destroyed
--   * a duplicated note presents a retired custody nonce  -> destroyed
--
-- Rotation is what makes duplication pointless rather than merely detectable at
-- redemption: every custody check retires the nonce and issues a new one, so the
-- moment either copy of a duped item is checked, the other is provably stale.
-- A dupe glitch therefore leaves exactly one surviving MAGI, never two.
--
-- Verification failures that are NOT a verdict (API down, timeout, no secret) never
-- destroy anything — the note is simply marked unverified.

hashimon_magi = hashimon_magi or {}

local modpath = core.get_modpath("hashimon_magi")

dofile(modpath .. "/api.lua")
dofile(modpath .. "/note.lua")
dofile(modpath .. "/custody.lua")
dofile(modpath .. "/commands.lua")

core.register_privilege("magi_admin", {
	description = "Issue MAGI into the vault (bounded by the supply cap)",
	give_to_singleplayer = true,
})
