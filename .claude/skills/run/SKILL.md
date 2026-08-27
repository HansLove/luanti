---
name: run
description: Run the Luanti stack headless — a dedicated Luanti server on a scratch port pointed at a Hashimon API (a local checkout under pnpm dev, or the remote one), plus scripted client joins — and read the logs. Use when asked to "run the server", "start the engine", "join as X", "run the mod against the API", "test the join flow", or to see a mod change working in the real engine instead of a Lua stub.
---

# Run the local stack

No GUI interaction: `bin/luanti --server` for the world, `bin/luanti --go` as a headless
client (works under WSLg). The mod talks to whichever Hashimon API `hashimon_api_url` names.

## 0. Mod precedence checklist

Before starting the engine, confirm which copy of each mod it will load:

- [ ] The engine is RUN_IN_PLACE: it loads `mods/` next to `bin/luanti`.
- [ ] On a mod name conflict, global `mods/` beats `worlds/<w>/worldmods/`. A copy in
      `worldmods/` with the same name is silently ignored.
- [ ] The mod version you want to run is the one under that `mods/` — a real directory or a
      symlink, both load the same.
- [ ] After start-up, `grep -E 'conflict|Overridden' $RUN_OUT/engine.log` is empty; if it
      prints `Overridden by: <path>`, that path is the copy actually loaded.

## 1. Preconditions

- Pick the API in `minetest.conf` (main checkout, gitignored):
  - local: `hashimon_api_url = http://127.0.0.1:4000`, with the `hashimon/server` repo
    running `pnpm dev` in the background against its Postgres — container or local daemon,
    whatever `DATABASE_URL` in its `.env` points to;
  - remote: `hashimon_api_url = https://server.ihashima.com`.
- `hashimon_server_secret` equal to the API's `LUANTI_SERVER_SECRET`;
  `secure.http_mods = hashimon_core`.
- Back up `worlds/hashidev/auth.sqlite` — every join adds a local row.

## 2. Start the dedicated server (background)

```bash
export RUN_OUT=/tmp/luanti-run; mkdir -p $RUN_OUT
bin/luanti --server --world worlds/hashidev --port 30099 --logfile $RUN_OUT/engine.log
```

Wait ~8 s, then check the mods loaded: `grep -E 'hashimon_core\]|conflict|Overridden|ERROR'
$RUN_OUT/engine.log`. Restart the server whenever a check needs fresh in-memory state.

## 3. Join

`scripts/join.sh NAME PASSWORD [SECONDS=20] [PORT=30099]` runs a headless client and prints the
relevant lines of both logs:

- `client exit=124` — the client stayed connected until the timeout: the join succeeded.
- `client exit=1` — the server refused: the `Access denied` line says why.

Full logs: `$RUN_OUT/client-NAME.log` and `$RUN_OUT/engine.log`; with a local API its
request log is the `pnpm dev` output. Several clients with different names can run at once.

DB check (local API): `psql "$DATABASE_URL" -c "<sql>"`, or `docker exec <container> psql ...`
when Postgres runs in a container.

## 4. Tear down

Stop clients, the server and `pnpm dev` if started; restore `auth.sqlite`; delete any test
players from the API's DB.
