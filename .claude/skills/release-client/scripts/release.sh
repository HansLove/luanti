#!/usr/bin/env bash
# Mechanical half of a Hashimon client release. The judgement half (which
# bump, how to word the notes) stays with the agent; this script only does
# what must be exact: list what changed, cut the tag, wait for CI, attach notes.
#
#   release.sh changes                 -> last client tag + commits since, grouped
#   release.sh next <patch|minor|major> -> print the next version number
#   release.sh publish <version> <notes.md> [--dry-run]
#                                       -> tag, push, wait for release_client, set notes
set -euo pipefail

TAG_PREFIX="client-v"
WORKFLOW="release_client.yml"

repo_root() { git rev-parse --show-toplevel; }
repo_slug() { gh repo view --json nameWithOwner -q .nameWithOwner; }

last_tag() {
	git tag -l "${TAG_PREFIX}*" --sort=-v:refname | head -n1
}

cmd_changes() {
	local last; last=$(last_tag)
	local range="HEAD"
	[ -n "$last" ] && range="${last}..HEAD"
	echo "last tag: ${last:-<none>}"
	echo "range:    $range"
	echo
	# conventional-commit prefix -> bucket; anything else lands in "other" so
	# nothing silently disappears from the notes
	git log --no-merges --format='%h %s' "$range" | awk '
		/^[0-9a-f]+ feat/  { f = f "\n" $0; next }
		/^[0-9a-f]+ fix/   { x = x "\n" $0; next }
		/^[0-9a-f]+ (chore|ci|test|docs|refactor|style|build)/ { i = i "\n" $0; next }
		{ o = o "\n" $0 }
		END {
			if (f) print "## features" f "\n"
			if (x) print "## fixes" x "\n"
			if (o) print "## other" o "\n"
			if (i) print "## internal (usually omitted from notes)" i "\n"
		}'
}

cmd_next() {
	local kind=${1:?usage: release.sh next <patch|minor|major>}
	local last; last=$(last_tag)
	local ver=${last#"$TAG_PREFIX"}
	IFS=. read -r major minor patch <<<"${ver:-0.0.0}"
	case "$kind" in
		patch) patch=$((patch + 1)) ;;
		minor) minor=$((minor + 1)); patch=0 ;;
		major) major=$((major + 1)); minor=0; patch=0 ;;
		*) echo "unknown bump: $kind" >&2; exit 2 ;;
	esac
	echo "${major}.${minor}.${patch}"
}

cmd_publish() {
	local version=${1:?usage: release.sh publish <x.y.z> <notes.md> [--dry-run]}
	local notes=${2:?usage: release.sh publish <x.y.z> <notes.md> [--dry-run]}
	local dry=${3:-}
	local tag="${TAG_PREFIX}${version}"

	[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be x.y.z, got '$version'" >&2; exit 2; }
	[ -s "$notes" ] || { echo "notes file '$notes' is empty or missing" >&2; exit 2; }
	git rev-parse -q --verify "refs/tags/$tag" >/dev/null && { echo "tag $tag already exists" >&2; exit 2; }
	[ -z "$(git status --porcelain)" ] || { echo "working tree is dirty; commit or drop changes first" >&2; exit 2; }
	# the tag must point at a commit origin already has, otherwise the
	# workflow checks out something nobody can reproduce
	git fetch -q origin
	git merge-base --is-ancestor HEAD "origin/$(git rev-parse --abbrev-ref HEAD)" \
		|| { echo "HEAD is not pushed to origin yet" >&2; exit 2; }

	local slug; slug=$(repo_slug)
	echo "tag:     $tag"
	echo "commit:  $(git log -1 --format='%h %s')"
	echo "repo:    $slug"
	echo "notes:   $notes"
	if [ "$dry" = "--dry-run" ]; then
		echo "(dry run) would: git tag -a $tag -F $notes && git push origin $tag"
		return
	fi

	git tag -a "$tag" -F "$notes"
	git push origin "$tag"

	# the workflow is registered a few seconds after the push lands
	local run_id=""
	for _ in $(seq 1 30); do
		run_id=$(gh run list --workflow "$WORKFLOW" --branch "$tag" --limit 1 --json databaseId -q '.[0].databaseId' || true)
		[ -n "$run_id" ] && break
		sleep 5
	done
	[ -n "$run_id" ] || { echo "no $WORKFLOW run appeared for $tag; check Actions manually" >&2; exit 1; }
	echo "run:     https://github.com/$slug/actions/runs/$run_id"

	# three platform builds plus packaging; ~10-40 min in practice
	gh run watch "$run_id" --exit-status --interval 30

	# the workflow creates the release with --generate-notes; overwrite with ours
	gh release edit "$tag" --repo "$slug" --notes-file "$notes"
	gh release view "$tag" --repo "$slug" --json url,assets -q '.url, (.assets[].name)'
}

case "${1:-}" in
	changes) cmd_changes ;;
	next) shift; cmd_next "$@" ;;
	publish) shift; cmd_publish "$@" ;;
	*) sed -n '2,10p' "$0"; exit 2 ;;
esac
