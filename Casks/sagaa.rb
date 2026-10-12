cask "sagaa" do
  version "1.1.0"
  sha256 "3ecc184b3f2f29cc4bee5c559197dc0246a5321b1448418ea852967d5eaf97b9"

  url "https://github.com/tklwin/sagaa/releases/download/v#{version}/Sagaa-macOS.dmg"
  name "Sagaa"
  desc "Ultra-fast, private, and lightweight offline Burmese speech-to-text dictation"
  homepage "https://github.com/tklwin/sagaa"

  depends_on macos: :ventura

  app "Sagaa.app"

  zap trash: [
    "~/Library/Application Support/Sagaa",
    "~/Library/Preferences/com.tklwin.sagaa.plist",
  ]
end

