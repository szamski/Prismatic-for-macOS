# Homebrew cask for Prismatic.
#
# Place this in a tap repository named `homebrew-tap` under your GitHub account
# (github.com/szamski/homebrew-tap → Casks/prismatic.rb), then users can:
#
#   brew install szamski/tap/prismatic
#
# After each release: run `scripts/notarize.sh`, upload `Prismatic.zip` to the GitHub
# release tagged `v<version>`, then update `version` and `sha256` below.

cask "prismatic" do
  version "1.0.0"
  sha256 "a21eae23c02eb1627f2fef95ac7390bcc1b5901e7be74f60e767b5397ebcaa7e"

  url "https://github.com/szamski/Prismatic-for-macOS/releases/download/v#{version}/Prismatic.zip"
  name "Prismatic"
  desc "Menu-bar RGB control for SteelSeries Arena 7 speakers"
  homepage "https://github.com/szamski/Prismatic-for-macOS"

  app "Prismatic.app"

  zap trash: [
    "~/Library/Preferences/szamowski.prismledmacos.plist",
  ]
end
