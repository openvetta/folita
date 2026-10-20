#!/bin/sh
# check-release-notes.sh 的回归测试：在临时仓库副本中构造各种发布说明。
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/scripts/release" "$work/.github/release-notes"
cp "$here/check-release-notes.sh" "$work/scripts/release/"
printf 'settings:\n  base:\n    MARKETING_VERSION: "9.9.9"\n' > "$work/project.yml"
check="$work/scripts/release/check-release-notes.sh"
notes="$work/.github/release-notes/v9.9.9.md"
failures=0

expect() {
    expected=$1; label=$2; shift 2
    if "$@" >/dev/null 2>&1; then actual=pass; else actual=fail; fi
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: $label (expected $expected, got $actual)"
        failures=$((failures + 1))
    else
        echo "ok: $label"
    fi
}

expect fail "missing file" "$check"
: > "$notes"
expect fail "empty file" "$check"
printf '## 新增\n\n- 一条新功能。\n\n## 其他\n\n- 内部调整。\n' > "$notes"
expect pass "valid notes" "$check"
expect fail "explicit version without notes" "$check" 1.0.0
printf '## Features\n\n- something\n' > "$notes"
expect fail "unknown section" "$check"
printf '## 新增\n\n' > "$notes"
expect fail "section without entries" "$check"

[ "$failures" -eq 0 ]
