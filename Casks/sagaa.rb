cask "sagaa" do
  version "1.1.1"
  sha256 "1a15ea5d3eb8de0c6760d59f5052ee6b59347254c66e1b48894235ec31970a1c"

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

