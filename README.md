# 🎙️ Vitroscribe

**Vitroscribe** is an autonomous, privacy-first macOS application that automatically detects when you join online meetings, records the audio, and transcribes the dialogue directly on your device.

Designed for absolute friction-less utility, Vitroscribe quietly monitors your system and handles the start/stop logic for your transcriptions completely invisibly.

## ✨ Key Features

* **🚀 Meeting Join HUD**: One minute before your scheduled meetings, a creative floating notification appears with a 10-second countdown. Join your call and start capturing the transcript with a single click via the **"Join & Capture"** button.
* **🤖 True Zero-Click Auto-Detection**: Uses advanced heuristic window scanning and browser URL scraping to identify exactly when you join and leave a meeting.
* **🌐 Broad Platform Support**: Natively detects and wraps around **Google Meet**, **Zoom**, **Microsoft Teams**, **Cisco Webex**, and **Slack Huddles**.
* **🔒 100% On-Device Privacy**: Transcriptions are processed entirely locally on your Mac using Apple's `SFSpeechRecognizer` framework. No audio data is ever sent to the cloud.
* **📅 Calendar Fallback Intelligence**: Intelligently syncs with your Google Calendar to trigger recordings and provide timely notifications.
* **⏱ Infinite Timeline Matrix**: Implements a custom absolute-millisecond timestamp ledger that stitches overlapping audio buffers together, guaranteeing zero dropped words.
* **🎨 Premium Centered UI**: A modern, clean interface with stable, centered navigation tabs (**Live**, **History**, **Settings**) and a smooth, spring-animated History sidebar.
* **🥷 Privacy Controls**: Toggle settings to hide the recording overlay or the meeting join HUD during screen shares, ensuring your desktop looks professional and clean for others.

## 🛠️ Technology Stack

* **SwiftUI** - Modern declarative UI with custom spring animations.
* **NavigationStack & Sidebar Architecture** - Fluid, seamless transitions and layout stability.
* **AVAudioEngine & SFSpeech** - Low-latency audio capture and ML transcription.
* **CoreAudio C-APIs** - Low-level hardware microphone flow monitoring.
* **SQLite.swift** - Local data persistence for historical meeting sessions.
* **osascript / CGWindowList** - Active process and browser DOM inspection via thread-safe processes.

## ⚙️ How it Works

1. **The Watcher:** A lightweight background thread polls your active windows and hardware microphone state every 2 seconds for high responsiveness.
2. **The HUD:** If a meeting is detected or scheduled via Google Calendar, Vitroscribe prompts you to join. Choosing "Join & Capture" instantly opens your meeting and readies the transcription.
3. **The Matrix Stitcher:** As you speak, Apple's Speech Recognition streams partial text. Vitroscribe injects these into a time-based ledger. Every 2 seconds of silence, it automatically breaks the text into clean paragraphs.
4. **The Stop:** The moment the meeting context is lost (window closed or URL left), Vitroscribe guarantees a final transcript commit and shuts down instantly to preserve RAM.

## 🚀 Getting Started

1. Clone the repository.
2. Generate the project via XcodeGen:
   ```bash
   xcodegen
   ```
3. Open `Vitroscribe.xcodeproj`.
4. Ensure your Mac's target is set to **macOS 14.0+**.
5. Build and run!

### 🎙️ Audio setup Note
Vitroscribe by default uses your **System Default Input Device**. 
* **For standard use**: It will work perfectly with your built-in microphone or headset.
* **To capture meeting audio (others speaking)**: It is recommended to use [BlackHole 2ch](https://existential.audio/blackhole/) or a similar loopback driver. Route your meeting output to BlackHole and set BlackHole as your system input. This allows Vitroscribe to "hear" both you and the other participants.

## 📜 License
[Insert License Here]
