#!/bin/sh
# 校验当前版本的发布说明：文件存在、非空，且只使用约定的小节标题。
# 用法：check-release-notes.sh [版本号]，省略时读取 project.yml 的 MARKETING_VERSION。
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
version=${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$root/project.yml" | head -n 1)}

if [ -z "$version" ]; then
    echo "error: cannot read MARKETING_VERSION from project.yml" >&2
    exit 1
fi

notes="$root/.github/release-notes/v$version.md"

if [ ! -s "$notes" ]; then
    echo "error: missing or empty release notes: .github/release-notes/v$version.md" >&2
    exit 1
fi

invalid=$(grep '^## ' "$notes" | grep -v -x -e '## 新增' -e '## 改进' -e '## 修复' -e '## 其他' || true)
if [ -n "$invalid" ]; then
    echo "error: unexpected section in v$version.md (allowed: 新增 / 改进 / 修复 / 其他):" >&2
    echo "$invalid" >&2
    exit 1
fi

if ! grep -q '^- ' "$notes"; then
    echo "error: v$version.md has no entries" >&2
    exit 1
fi

echo "release notes ok: v$version"
