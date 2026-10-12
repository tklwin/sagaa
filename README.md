# 🎙️ Sagaa (စကား)

> **Ultra-fast, private, and lightweight offline Burmese speech-to-text dictation for macOS.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-black?logo=apple)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon-blue)](https://apple.com)
[![Engine](https://img.shields.io/badge/Engine-CoreML%20%7C%20Neural%20Engine-orange)](https://developer.apple.com/machine-learning/core-ml/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**Sagaa** is a native macOS speech-to-text dictation tool designed specifically for the Burmese (Myanmar) language. Built in pure Swift using Apple CoreML, it runs entirely on-device with zero cloud latency and complete privacy.

---

## ✨ Features

* ⚡ **Blazing Fast**: **~25 ms** warm inference latency on the Apple Neural Engine (ANE) and Apple Silicon GPU.
* 🔒 **100% Private & Offline**: Audio is never sent to the cloud. Everything is processed locally on your Mac.
* 🪶 **Featherlight**: Consumes **< 50 MB RAM** — no Electron, no Python runtime overhead.
* 🎯 **Accurate Burmese**: Powered by a 23.8M Conformer CTC model trained specifically on Myanmar speech datasets (OpenSLR-80).
* ⌨️ **Universal Dictation**: Lives in the macOS Menu Bar. Speak in Burmese, and your transcription is automatically pasted right at your cursor in any app (Telegram, Notes, Word, Browser, etc.).

---

## 🏗️ Architecture

```
┌────────────────────────┐
│   Microphone (16kHz)   │
└───────────┬────────────┘
            │ AVAudioEngine
            ▼
┌────────────────────────┐
│ vDSP Mel-Spectrogram   │ 80-bin Filterbank (Accelerate)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│ Apple CoreML Engine    │ BurmeseASR.mlpackage (38 MB)
│  (Neural Engine / GPU) │ ~25ms Inference Latency
└───────────┬────────────┘
            │ CTC Greedy Decode (vocab.json)
            ▼
┌────────────────────────┐
│   Target Application   │ Direct text injection (Cmd+V)
└────────────────────────┘
```

---

## 📦 Installation

### 1. Download DMG
Download the latest `Sagaa-macOS.dmg` from the **[Releases](../../releases)** page, open it, and drag `Sagaa.app` into your Applications folder.

### 2. Homebrew Cask (Coming Soon)
```bash
brew tap tklwin/sagaa
brew install --cask sagaa
```

---

## 🛠️ Building from Source

### Automated Cloud Build (GitHub Actions)
This repository includes a pre-configured GitHub Actions workflow (`.github/workflows/build-release.yml`) that compiles the CoreML model and generates a distributable `.dmg` on Apple Silicon runners.

### Local Build (macOS with Xcode 15+)
```bash
# 1. Compile CoreML model package
xcrun coremlc compile Models/BurmeseASR.mlpackage Models/

# 2. Build Swift Release Binary
swift build -c release
```

---

## 🗺️ Roadmap

- [x] Conformer CTC PyTorch ➔ Apple CoreML FP16 export (38 MB).
- [x] vDSP Accelerate audio DSP Mel Spectrogram extractor.
- [x] Native Swift menu bar app structure.
- [x] GitHub Actions automated `.dmg` packaging pipeline.
- [ ] Non-activating floating HUD pill with live audio waveform.
- [ ] User custom dictionary & fine-tuning support.

---

## 📜 Credits & Acknowledgments

- **Burmese ASR Model**: [freococo/myanmar_asr](https://huggingface.co/freococo/myanmar_asr) by freococo (Licensed under **Apache 2.0**).
- **Training Corpus**: OpenSLR-80 Burmese Speech Corpus.

---

## 📄 License

Licensed under the [Apache License, Version 2.0](LICENSE).
