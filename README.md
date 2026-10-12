# Sagaa (စကား)

> **Ultra-fast, private, and lightweight offline Burmese speech-to-text dictation for macOS.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B%20(Ventura%2B)-black?logo=apple)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1%2FM2%2FM3%2FM4)-blue)](https://apple.com)
[![Engine](https://img.shields.io/badge/Engine-End--to--End%20CoreML%20%7C%20Apple%20Neural%20Engine-orange)](https://developer.apple.com/machine-learning/core-ml/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**Sagaa** is a native macOS menu bar dictation tool designed specifically for the Burmese (Myanmar) language. Built in pure Swift using an End-to-End CoreML engine, it runs 100% locally on Apple Silicon with zero cloud dependencies and sub-30ms latency.

Inspired by the native macOS architecture of **vorssaint-utils** and the intuitive dictation workflow of **Handy**.

---

## ✨ Key Features

* ⚡ **End-to-End Neural Speed**: **~24 ms** warm inference latency running directly on the Apple Neural Engine (ANE) and GPU.
* 🔒 **100% Offline & Private**: Zero audio data ever leaves your Mac. No network connection required.
* 🪶 **Ultra Lightweight**: Consumes **< 45 MB RAM** — native Swift AppKit & SwiftUI with zero webview overhead.
* 🎯 **Accurate Burmese Recognition**: 23.8M Conformer CTC model trained on Myanmar speech datasets (OpenSLR-80).
* 📝 **Natural Word Flow (သဘာဝ စာလုံးပေါင်း စနစ်)**: Grammatical syllable-to-word rejoining that automatically turns disjointed syllables into natural, properly-spaced Burmese words.
* ⌨️ **Universal Zero-Permission Hotkey**: Uses Carbon `RegisterEventHotKey` for instantaneous toggling with `⌃⌥S` (`Control + Option + S`) anywhere in macOS.
* 📋 **Bulletproof Auto-Paste**:
  - Automatically restores target application window focus.
  - Monitors physical keyboard modifier states (`Control`, `Option`) and releases them before sending `Cmd+V`.
  - Configurable paste delay in Settings.
* ⚙️ **Dedicated Settings Window (`⌘,`)**:
  - **General**: Launch at login (`SMAppService`), auto-paste toggle, paste delay selector, sound feedback.
  - **Dictation**: Natural Burmese word flow switch, ANE engine specs, latency counters.
  - **Shortcuts**: Shortcut reference and configuration.
  - **History**: Searchable list of recent transcriptions with 1-click clipboard copy and latency benchmarks.
  - **Permissions**: Live status for Microphone & Accessibility, 1-click authorization prompts, and a "Reset Stale Permission" recovery utility.
  - **About**: Version information, open-source licenses, and repository links.
* 🔔 **Auditory & Visual Feedback**: Subtle start/stop audio cues and live audio level waveform visualizer.

---

## 🏗️ End-to-End Architecture

```
┌──────────────────────────────────────┐
│       Microphone (16kHz PCM)         │
└──────────────────┬───────────────────┘
                   │ AVAudioEngine
                   ▼
┌──────────────────────────────────────┐
│     End-to-End CoreML Pipeline       │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 1D-Conv STFT + Mel Filterbank  │  │ (Embedded inside CoreML graph)
│  └────────────────┬───────────────┘  │
│                   ▼                  │
│  ┌────────────────────────────────┐  │
│  │ Conformer CTC Encoder (23.8M)  │  │ (Apple Neural Engine / GPU Float16)
│  └────────────────────────────────┘  │
└──────────────────┬───────────────────┘
                   │ Fast Memory-Strided CTC Greedy Decoder
                   ▼
┌──────────────────────────────────────┐
│   Burmese Syllable-to-Word Rejoiner  │ (Natural spacing & orthography)
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  Target App Focus & Text Injector    │ (Modifier-safe Cmd+V injection)
└──────────────────────────────────────┘
```

---

## 🚀 Installation

### Option 1: Homebrew Cask (Recommended)

```bash
# Add the tap
brew tap tklwin/sagaa

# Install Sagaa
brew install --cask sagaa
```

### Option 2: Direct DMG Download

1. Download `Sagaa-macOS.dmg` from the **[Latest Release](https://github.com/tklwin/sagaa/releases/latest)**.
2. Open the DMG and drag **Sagaa** to your **Applications** folder.
3. Launch **Sagaa** from Applications or Spotlight.

---

## ⌨️ How to Use

1. Launch Sagaa. A waveform icon (`waveform`) will appear in your macOS Menu Bar.
2. Place your cursor into any app (e.g. TextEdit, Notes, Telegram, Slack, VS Code, Browser).
3. Press **`⌃⌥S`** (`Control + Option + S`) or click the Menu Bar icon to start dictation.
4. Speak in Burmese (e.g. *"မင်္ဂလာပါ ခင်ဗျာ"*).
5. Press **`⌃⌥S`** again to finish. Sagaa instantly transcribes and pastes the text directly at your cursor!

> **Left-Click Menu Bar Icon**: Opens the quick SwiftUI Popover panel.  
> **Right-Click Menu Bar Icon**: Opens the standard macOS native context menu.  
> **Open Preferences**: Press **`⌘,`** or select **Settings...** from the menu.

---

## 🛠️ Building from Source

### Prerequisites
- macOS 13.0 (Ventura) or newer on Apple Silicon (M1/M2/M3/M4).
- Xcode Command Line Tools (`xcode-select --install`).

### Build, Install, or Package DMG

Use the included build script:

```bash
# 1. Compile in Release mode
./build.sh

# 2. Build and install directly to /Applications/Sagaa.app
./build.sh --install

# 3. Build and package a production DMG in dist/
./build.sh --dmg

# 4. Clean build artifacts
./build.sh --clean
```

---

## 🔒 Permissions & Privacy

- **Microphone**: Needed to capture live audio input. Requested on first recording.
- **Accessibility**: Needed strictly to inject `Cmd+V` into your active target application.
- **Resetting Accessibility**: If macOS displays Sagaa as enabled in System Settings but text injection fails, open **Settings > Permissions** and click **"Reset Permission"** to clear stale code signature entries.

---

## 📜 Credits & License

- **ASR Conformer Model**: [freococo/myanmar_asr](https://huggingface.co/freococo/myanmar_asr) by freococo (Licensed under **Apache 2.0**).
- **Dataset**: OpenSLR-80 Burmese Speech Corpus.
- **Application Code**: Licensed under the **[Apache License 2.0](LICENSE)**.
