#!/usr/bin/env bash
# Move submodule pins to the tip of each submodule's `branch` (from
# .gitmodules), one submodule at a time. A submodule that can't be
# updated (for example a private repo we have no credentials for) gets
# a warning and keeps its old pin; the others still move.
#
# Usage: scripts/bump-pins.sh [path...]    default: every submodule
#
# This checks out the new commits in each submodule's working tree
# (detached HEAD), the same as `git submodule update --remote`.
# The new pins are left unstaged; review them with `git diff`.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

warn() {
	echo "warning: $*" >&2
	# Shown as an annotation on the GitHub Actions run.
	if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$*"; fi
}

if [ $# -eq 0 ]; then
	set -- $(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
fi

for path in "$@"; do
	if ! git submodule update --init --remote --quiet -- "$path"; then
		warn "$path: could not update to the tip of its branch; pin unchanged"
	fi
done

git --no-pager diff --submodule=log
