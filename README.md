# 🎙️ Vitroscribe

**Vitroscribe** is an autonomous, privacy-first macOS menu bar application that automatically detects when you join online meetings, records the audio, and transcribes the dialogue directly on your device without requiring you to lift a finger.

Designed for absolute friction-less utility, Vitroscribe quietly monitors your system and handles the start/stop logic for your transcriptions completely invisibly. 

## ⬇️ Download
Ready to test the application? 
**[Download the latest Vitroscribe DMG Installer here](https://insert-your-dmg-link-here.com)**

## ✨ Key Features

* **🤖 True Zero-Click Auto-Detection**: Uses advanced heuristic window scanning and browser URL scraping to identify exactly when you join and leave a meeting. 
* **🌐 Broad Platform Support**: Natively detects and wraps around **Google Meet**, **Zoom**, **Microsoft Teams**, **Cisco Webex**, and **Slack Huddles** (including floating overlays and embedded calls).
* **🔒 100% On-Device Privacy**: Transcriptions are processed entirely locally on your Mac using Apple's `SFSpeechRecognizer` framework. No audio data is ever sent to the cloud.
* **📅 Calendar Fallback Intelligence**: If strict security permissions block window scraping, Vitroscribe intelligently falls back to syncing with your Google Calendar to trigger recordings during scheduled meeting blocks.
* **⏱ Infinite Timeline Matrix**: Implements a custom absolute-millisecond timestamp ledger that stitches overlapping audio buffers together, guaranteeing zero dropped words or duplicated sentences.
* **🥷 Stealth Menu Bar UI**: Runs entirely as a background agent (`LSUIElement`). Access your real-time live captions and searchable past meeting history from a clean, lightweight drop-down menu in your Mac's top bar.

## 🛠️ Technology Stack

* **SwiftUI** - UI and reactive state management.
* **AVAudioEngine & SFSpeech** - Low-latency audio capture and ML transcription.
* **CoreAudio C-APIs** - Low-level hardware microphone flow monitoring.
* **SQLite.swift** - Highly reliable local data persistence for historical meeting logs.
* **AppleScript / CGWindowList** - Active process and browser DOM inspection.

## ⚙️ How it Works

1. **The Watcher:** A lightweight background thread polls your active windows and hardware microphone state every 5 seconds.
2. **The Matrix Sticher:** As you speak, Apple's Speech Recognition streams partial text. Vitroscribe injects these partials into a time-based ledger. Every 2 seconds of silence, it automatically breaks the generated text into clean paragraphs.
3. **The Ledger:** Every 5 seconds, the application transparently commits the reconstructed transcript to a local SQLite database in your Application Support directory.
4. **The Stop:** The moment you close the meeting window or leave a Slack Huddle (and the hardware microphone interface closes), Vitroscribe guarantees a final transcript commit and shuts down its audio engines instantly to preserve RAM.

## 🚀 Getting Started (for Development)

*(Note: Vitroscribe requires [BlackHole 2ch](https://existential.audio/blackhole/) or a similar Aggregate Audio Device to capture both input microphone and output system speaker audio simultaneously).*

1. Clone the repository.
2. Generate the project via XcodeGen:
   ```bash
   xcodegen
   ```
3. Open `Vitroscribe.xcodeproj`.
4. Ensure your Mac's target is set to **macOS 14.0+**.
5. Build and run! You will be prompted for Screen Recording, Microphone, and Speech Recognition permissions on first launch.

## 📜 License
[Insert License Here]
