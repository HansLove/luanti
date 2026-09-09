---
name: cpp-lint-check
description: Run clang-tidy with this repo's own .clang-tidy config against C++ files under src/, irr/, or lib/, and return real file:line diagnostics — the same checks the cpp_lint.yml CI job enforces, but on just the files you touched, before waiting for CI to catch it. Use this whenever the user asks to "run clang-tidy", "lint this C++", "check this against clang-tidy", "cpp-lint-check", "revisa este C++ con clang-tidy", or right after editing any .cpp/.c/.h file under src/, irr/, or lib/ — don't wait to be asked explicitly, offer it proactively once such a file has changed. This is the tool-executing counterpart to the cpp-reviewer agent, which reasons about the diff but never actually runs clang-tidy; reach for this skill when the user wants a real compiler-backed diagnostic instead of a reasoned opinion.
---

# C++ lint check

Runs clang-tidy on specific C++ files using this repo's real `.clang-tidy`
config, so you get the same class of diagnostic `cpp_lint.yml` would produce
in CI — but scoped to the files that just changed, and in seconds instead of
waiting for a CI run.

## Why scoped, not full-tree

CI's `util/ci/clang-tidy.sh` lints the entire `src/.*` tree, which requires a
full CMake configure and a couple of build targets first. That's the right
tradeoff for CI, but not for a quick check after editing two files. This skill
reuses the exact same `.clang-tidy` config and the same file scope
(`src/`, `irr/`, `lib/`), just applied to a handful of files at a time.

## Running it

Use the bundled script — it already knows the repo's scope, config path, and
the clang-tidy version CI expects, and it fails loudly instead of silently
skipping checks it couldn't run:

```bash
.claude/skills/cpp-lint-check/scripts/cpp-lint.sh <file1> <file2> ...
# or, to lint whatever changed since HEAD:
.claude/skills/cpp-lint-check/scripts/cpp-lint.sh --diff
```

The script:

1. Filters the given files down to `src/**`, `irr/**`, `lib/**` — the same
   scope `.github/workflows/cpp_lint.yml` lints. A file outside that scope is
   skipped with a note, not silently ignored and not treated as an error.
2. Looks for a clang-tidy binary, preferring `clang-tidy-15` (what CI pins)
   and falling back through `clang-tidy-16`, `clang-tidy-14`, then a bare
   `clang-tidy`. If none exist on `PATH`, it stops and says so — a missing
   binary should never look like "no issues found."
3. Checks for `build/compile_commands.json`. clang-tidy needs this compile
   database to resolve include paths and flags correctly; without it,
   diagnostics are unreliable or clang-tidy simply can't parse the file.
   Configuring a build (a CMake configure plus two build targets) is a
   real, somewhat costly step — this skill never runs it automatically.
   If the database is missing, the script prints the exact commands (from
   `util/ci/clang-tidy.sh`) and stops so the user or Claude can decide to run
   them.
4. Runs `clang-tidy -p build --config="$(cat .clang-tidy)" <files>` and
   prints the raw output.

## Reading the output

clang-tidy's output is already `file:line:column: warning: ... [check-name]`
— report it to the user close to verbatim rather than re-summarizing it into
something vaguer. If you also have the `cpp-reviewer` agent's findings on the
same files, note where they agree (extra confirmation) and where clang-tidy
caught something the reasoning-only review missed (or vice versa) — the two
are complementary, not redundant.

If the compile database is stale (files renamed, new files added since the
last configure) clang-tidy will complain about a missing entry per file
rather than crashing outright; mention that the fix is re-running the CMake
configure step, not something this skill should paper over.
