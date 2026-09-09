#!/usr/bin/env bash
# Run clang-tidy, with this repo's own .clang-tidy config, over a specific set
# of C++ files. Mirrors the scope and config of util/ci/clang-tidy.sh and
# .github/workflows/cpp_lint.yml, but on the handful of files passed in
# instead of the whole src/.* tree.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

usage() {
	echo "Usage: $0 <file.cpp|file.h> [more files...]" >&2
	echo "       $0 --diff   # lint files changed vs. HEAD" >&2
}

if [[ $# -eq 0 ]]; then
	usage
	exit 1
fi

if [[ "$1" == "--diff" ]]; then
	mapfile -t candidates < <(git diff --name-only HEAD -- 'src/*.cpp' 'src/*.c' 'src/*.h' \
		'irr/*.cpp' 'irr/*.c' 'irr/*.h' 'lib/*.cpp' 'lib/*.c' 'lib/*.h')
else
	candidates=("$@")
fi

# Keep only files that are (a) still on disk (not deleted) and (b) inside the
# same scope cpp_lint.yml lints — clang-tidy has nothing useful to say about
# files outside src/, irr/, lib/.
files=()
for f in "${candidates[@]}"; do
	case "$f" in
	src/*.cpp | src/*.c | src/*.h | irr/*.cpp | irr/*.c | irr/*.h | lib/*.cpp | lib/*.c | lib/*.h)
		if [[ -f "$f" ]]; then
			files+=("$f")
		fi
		;;
	*)
		echo "Skipping $f (outside src/, irr/, lib/ — not part of cpp_lint.yml's scope)" >&2
		;;
	esac
done

if [[ ${#files[@]} -eq 0 ]]; then
	echo "No lintable C++ files to check." >&2
	exit 0
fi

# CI pins clang-tidy-15; fall back to nearby versions or a bare clang-tidy on
# a dev machine rather than failing just because the binary isn't named
# exactly what CI expects.
clang_tidy_bin=""
for candidate in clang-tidy-15 clang-tidy-16 clang-tidy-14 clang-tidy; do
	if command -v "$candidate" >/dev/null 2>&1; then
		clang_tidy_bin="$candidate"
		break
	fi
done

if [[ -z "$clang_tidy_bin" ]]; then
	echo "error: no clang-tidy binary found on PATH (tried clang-tidy-15, clang-tidy-16, clang-tidy-14, clang-tidy)." >&2
	echo "Install one (matching CI's clang-tidy-15 if possible) before running this check." >&2
	exit 1
fi

if [[ ! -f build/compile_commands.json ]]; then
	cat >&2 <<'EOF'
error: build/compile_commands.json not found.

clang-tidy needs the compile database to know each file's include paths and
flags. This repo has not been configured for it yet. That's a one-time,
somewhat costly step (a CMake configure + two build targets), so this script
won't do it on its own — run it yourself when you're ready:

  cmake -B build -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DRUN_IN_PLACE=TRUE -DENABLE_GETTEXT=FALSE -DBUILD_SERVER=TRUE
  cmake --build build --target GenerateVersion GenerateBuiltinFilesCpp

Then re-run this script.
EOF
	exit 1
fi

echo "Running $clang_tidy_bin on ${#files[@]} file(s):" >&2
printf '  %s\n' "${files[@]}" >&2

"$clang_tidy_bin" -p build --config="$(cat .clang-tidy)" "${files[@]}"
