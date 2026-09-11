One or two sentences: what this release means for a player. Lead with the
most visible change, mention the rest in passing.

## Downloads

| Platform | File | Notes |
|---|---|---|
| Windows 10/11 (64-bit) | `hashimon-client-win64.exe` | Self-extracting launcher. Run it, pick a folder, play. |
| macOS (Apple Silicon) | `hashimon-client-macos-arm64.zip` | Unzip and drag `luanti.app` to Applications. |
| macOS (Intel) | `hashimon-client-macos-x86_64.zip` | Same as above. |

The macOS app is not notarized yet: on first launch, right-click the app and
choose Open, or run `xattr -dr com.apple.quarantine /Applications/luanti.app`.

## What's new

- **Bold hook**: one sentence a player understands, no file names.

## Fixes

- What was broken, from the player's point of view, and that it now works.

## Under the hood

- Optional. Build, CI, or engine changes worth knowing about for people who
  run their own client. Drop the section if empty.

**Full changelog**: https://github.com/HansLove/luanti/compare/client-vPREV...client-vNEW
