# 发布流水线以此为模板生成 nbecloud/homebrew-tap 中的 Casks/folita.rb。
cask "folita" do
  version "{{VERSION}}"
  sha256 "{{SHA256}}"

  url "https://github.com/nbecloud/folita/releases/download/v#{version}/Folita-#{version}.zip"
  name "Folita"
  desc "Clipboard manager with a Liquid Glass panel"
  homepage "https://github.com/nbecloud/folita"

  auto_updates true
  depends_on macos: ">= :tahoe"

  app "Folita.app"

  zap trash: [
    "~/Library/Containers/app.folita.Folita",
  ]
end
