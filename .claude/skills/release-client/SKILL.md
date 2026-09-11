---
name: release-client
description: Cut a new Hashimon client release end to end - version, player-facing release notes, tag, build, published release. Use this whenever the user wants to ship, publish, tag, or release the client: "release the client", "new client release", "cut a release", "publish version 0.2.0", "saca un release", "nuevo release del cliente", "sube la version del cliente", "haz el tag client-v", or asks what would go into the next release or what changed since the last one. Also use it when the user just says "release" inside this repo - the only thing this repo releases is the client. Do not use it for the server Docker deploy (deploy.yml) or for Luanti's own bump_version.sh, which versions the engine, not the client.
---

# Release the Hashimon client

A client release is one annotated tag, `client-v<x.y.z>`, pushed to origin;
`.github/workflows/release_client.yml` builds and publishes from there. Its
`--generate-notes` body is a bare commit list: this skill replaces it with
notes a player can read, on a tag cut over a commit origin already has.

The client version lives only in the tag. `CMakeLists.txt` still carries
Luanti's own version (5.x); the workflow stamps the client version through
`VERSION_EXTRA=hashimon-<x.y.z>`. Do not touch `util/bump_version.sh`.

## Steps

All commands run from the repo root.

### 1. See what changed

```bash
.claude/skills/release-client/scripts/release.sh changes
```

Prints the last tag and the commits since, bucketed by conventional-commit
prefix (features, fixes, other, internal). If the range is empty, stop and
tell the user there is nothing to release.

### 2. Pick the bump

- **patch** when everything is fixes or internal work.
- **minor** when there is at least one `feat` a player would notice.
- **major** only if the user asks, or a change breaks saved worlds or logins.

```bash
.claude/skills/release-client/scripts/release.sh next minor   # prints e.g. 0.2.0
```

### 3. Write the notes

Copy `assets/notes-template.md` to the scratchpad and fill it in. The notes
are the GitHub release body, so they are read by players scrolling the
Releases page, not by whoever wrote the commits. That drives every rule below.

- Describe outcomes, not commits. "Login now goes straight to the Hashimon
  dialog" beats "replace the main menu with a single login dialog".
- Skip `chore`, `ci`, `test`, `refactor` commits unless they change what a
  player experiences.
- No emojis.

Show the finished notes to the user before publishing. This is the one step
where their opinion changes the output, and it costs nothing to ask now
versus editing a published release later.

### 4. Publish

```bash
.claude/skills/release-client/scripts/release.sh publish 0.2.0 notes.md --dry-run
.claude/skills/release-client/scripts/release.sh publish 0.2.0 notes.md
```

Builds take 10 to 40 minutes: run `publish` in the background and give the
user the run URL as soon as the script prints it.

### 5. Report

Give the user the release URL and the three asset names the script prints at
the end. If the run fails, do not retag: fix, push, and cut the next patch
version. A tag that already points at a bad commit stays where it is; moving
tags breaks anyone who already fetched it.