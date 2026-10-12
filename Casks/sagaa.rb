cask "sagaa" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/tklwin/sagaa/releases/download/v#{version}/Sagaa-macOS.dmg"
  name "Sagaa"
  desc "Ultra-fast, private, and lightweight offline Burmese speech-to-text dictation"
  homepage "https://github.com/tklwin/sagaa"

  depends_on macos: ">= :ventura"

  app "Sagaa.app"

  zap trash: [
    "~/Library/Application Support/Sagaa",
    "~/Library/Preferences/com.tklwin.sagaa.plist",
  ]
end

