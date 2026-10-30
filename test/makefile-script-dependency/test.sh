#!/bin/bash

# This test demonstrates that the Makefile rebuilds HTML targets when a file
# inside a script directory changes, but not when only markdown or dotfiles change.
#
# test/script-dir/test.sh proves single.sh notices such changes. This test proves
# that make actually invokes single.sh when they happen.

set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

# shellcheck disable=SC1091
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

MAKE=$(command -v gmake || command -v make)
makefile="$PROJECT_ROOT/Makefile"
target="build/index.html"
footer="scripts/html/10_addFooter/footer.html"

# Work in a copy, so build/ and .cache/ don't land in the test fixtures
workDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
cp -R "$testDir/source" "$testDir/scripts" "$workDir"
cd "$workDir" || exit 1

# Echoes "true" if make thinks the target is up to date, "false" if it would rebuild it.
# Uses an if, so that make's nonzero exit doesn't trip the test library's ERR trap.
isUpToDate() {
    if "$MAKE" -q -f "$makefile" "$target" >/dev/null 2>&1; then echo true; else echo false; fi
}

# First build
"$MAKE" -f "$makefile" "$target"
assert "target was built" "-f $target"
assert "target contains original footer" "$(grep -c FOOTER-ORIGINAL "$target") == 1"
assert "target is up to date after build" "$(isUpToDate) == true"

# make compares whole-second mtimes on the target, so make sure edits are later
sleep 1

# Change a dependent file inside the script directory
echo "<footer>FOOTER-CHANGED</footer>" > "$footer"
assert "changing a script dir file makes target stale" "$(isUpToDate) == false"
"$MAKE" -f "$makefile" "$target"
assert "target contains changed footer" "$(grep -c FOOTER-CHANGED "$target") == 1"
assert "target no longer contains original footer" "$(grep -c FOOTER-ORIGINAL "$target" || true) == 0"

sleep 1

# Markdown and dotfiles inside the script directory are ignored
echo "edited" >> scripts/html/10_addFooter/README.md
assert "changing a markdown file does not make target stale" "$(isUpToDate) == true"
echo "edited" >> scripts/html/10_addFooter/.editorconfig
assert "changing a dotfile does not make target stale" "$(isUpToDate) == true"

rm -rf "$workDir"
exit 0
