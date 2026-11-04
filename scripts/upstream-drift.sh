#!/usr/bin/env bash
# For each submodule with an `upstream` key in .gitmodules, list the
# commits on its `upstream-ref` (a branch or tag) that the tip of its
# ChameleonCloud `branch` doesn't contain. Output looks like
# `git diff --submodule=log`; forks that are up to date print nothing.
#
# Usage: scripts/upstream-drift.sh
#
# Read-only: fetches into the submodules but doesn't move their
# checkouts. Counts by ancestry, so an upstream fix we cherry-picked
# (new hash) is still listed.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

warn() {
	echo "warning: $*" >&2
	# Shown as an annotation on the GitHub Actions run.
	if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$*"; fi
}

git config -f .gitmodules --get-regexp '^submodule\..*\.upstream$' |
while read -r key upstream; do
	name=${key#submodule.}
	name=${name%.upstream}
	path=$(git config -f .gitmodules "submodule.$name.path")
	branch=$(git config -f .gitmodules "submodule.$name.branch")
	ref=$(git config -f .gitmodules "submodule.$name.upstream-ref")

	# Clone only if missing, so an existing checkout isn't moved.
	if [ ! -e "$path/.git" ] && ! git submodule update --init --quiet -- "$path"; then
		warn "$path: could not clone; not checked"
		continue
	fi
	if ! git -C "$path" fetch --quiet origin "$branch"; then
		warn "$path: could not fetch $branch from origin; not checked"
		continue
	fi
	# Fetch last, so FETCH_HEAD is the upstream ref.
	if ! git -C "$path" fetch --quiet "$upstream" "$ref"; then
		warn "$path: upstream-ref $ref not found at $upstream; update .gitmodules"
		continue
	fi

	commits=$(git -C "$path" log --no-merges --format='  > %s' "origin/$branch..FETCH_HEAD")
	if [ -n "$commits" ]; then
		echo "Submodule $path $branch..$ref:"
		echo "$commits"
	fi
done
