#!/bin/sh
# 把 design/app-icons/*.icon（Icon Composer 文档）按 macOS 系统蒙层渲染成 PNG，
# 生成设置页缩略图、菜单栏图标与剪贴面板顶标使用的 Folita/Resources/Assets.xcassets/AppIcon-<名称>.imageset。
# 修改图标源后运行：make app-icons。
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
catalog="$root/Folita/Resources/Assets.xcassets"

if [ ! -x "$ictool" ]; then
    echo "error: ictool not found, install Xcode 26 or later" >&2
    exit 1
fi

mkdir -p "$catalog"
[ -f "$catalog/Contents.json" ] || printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$catalog/Contents.json"

for icon in "$root"/design/app-icons/*.icon; do
    name=$(basename "$icon" .icon)
    set_dir="$catalog/AppIcon-$name.imageset"
    png="$set_dir/$name.png"
    rm -rf "$set_dir"
    mkdir -p "$set_dir"
    # 512 px 作为 256 pt 的 @2x，足够覆盖菜单栏小图标与设置页缩略图。
    "$ictool" "$icon" --export-image --output-file "$png" \
        --platform macOS --rendition Default --width 512 --height 512 --scale 1 >/dev/null
    swift "$root/scripts/icons/flatten-png.swift" "$png"
    cat > "$set_dir/Contents.json" <<EOF
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x"
    },
    {
      "filename" : "$name.png",
      "idiom" : "mac",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
done
