# On-device models

A-Coder Mobile can run LFM3 locally. No desktop bridge, no cloud, no network
after setup.

The on-device hub lives at **On-device** in the app, on Android only in v1
(also reachable there from the pairing screen, the home memory icon and
Settings). Omni is recommended.

## Platform support (v1)

The on-device surface is **Android-only in v1**. That is a board scope decision
(2026-11-19, THE-105 card `30ec2894`), not a build failure. Every iOS entry
point is gated: the four `/local*` routes, the pairing-screen link, the home
memory icon and the Settings row. On iOS the routes stay registered but resolve
to an "On-device models are Android-only in v1" screen instead of the hub, and
no `LocalModelsScreen`/`LocalChatScreen` is constructed. iOS v1 ships pairing +
chat. The gate and its widget test are THE-110.

Verified for THE-110 on 2026-11-20:

- `flutter build ios --release --no-codesign` **succeeds**. CI job
  `iOS build / unsigned-ipa` run `44527249107` (`main`, 2026-11-19) and run
  `44068833043` (PR #3, 2026-11-17) both concluded success.
- The unsigned IPA **does contain a native runtime**.
  `Payload/Runner.app/Frameworks/llamadart.framework` is a 15.8 MB Mach-O arm64
  library carrying llama.cpp/ggml, `mtmd` audio and the `llama_dart_tts_*` LFM3
  speech symbols, built for
  `target=iOS-arm64-iphoneos-arm64; backends=cpu,metal`. The `llamadart` build
  hook supplies it even though `pubspec.yaml` only names Android below
  `llamadart_native_backends.platforms`.
- No load attempt was executed on iOS: there is no iOS device in the QA set.
  `LocalChatController.loadModel` wraps `LlamaEngine.load` in a try/catch and
  surfaces failures as `state.error`, but v1 never exercises that path because
  the UI cannot reach it.

The runtime being present does not put iOS in scope. iOS LFM3 is unvalidated
(load time, RAM headroom, thermals, speech output), and the release QA set has
no iPhone. Revisit after v1 if the board wants on-device models on iOS.

## Models

| Mode | Model | Files | Use |
|---|---|---:|---|
| Omni (recommended) | `LFM3-Omni-2B` Q4_K_M | 1.10 GB + 0.28 GB mmproj | Text, images, audio in; text or speech out |
| Text | `LFM3-1.7B` Q4_K_M | 1.10 GB | Fast text chat |
| Voice | `LFM3-Audio-2B` Q4_K_M | 1.10 GB + 0.17 GB mmproj | Speech in; LFM3 speech out |

All are under the **LFM Open License v1.0**. Commercial use is subject to its
annual-revenue threshold and attribution terms. Models are not bundled in the
APK.

## Hardware

- arm64 Android device (the release APK is arm64-only because of the native
  runtime).
- 6–8 GB RAM is comfortable; 4 GB is borderline once Android and the app are
  resident.
- Keep at least 2 GB free for the model plus staging.
- The model is memory-mapped from app-private storage, so it must be a real
  GGUF file, not a compressed asset.

## Setup

1. Install the arm64 APK.
2. Transfer the GGUF files to the phone, or download them from the model screen.
3. Open **On-device → Omni** (or Text/Voice).
4. **Import GGUF** opens two pickers for Omni/Audio: the main model first, then
   the `mmproj` projector.
   - Omni: `LFM3-Omni-2B-Q4_K_M.gguf` + `mmproj-LFM3-Omni-2B-Q4_K_M.gguf`
   - Audio: `LFM3-Audio-2B-Q4_K_M.gguf` + `mmproj-LFM3-Audio-2B-Q4_K_M.gguf`
   - Text: `LFM3-1.7B-Q4_K_M.gguf`
5. Load the model and chat.

Downloads are resumable only at the file level (a partial `.part` is discarded
on failure). Import is the preferred path for low-bandwidth users.

## Features

- Streaming text with a separate, collapsible **Thinking** block.
- Markdown for assistant replies, with horizontally scrolling code blocks and a
  copy button.
- Image attachments with a caption preview before sending.
- Push-to-talk at 16 kHz mono; **Cancel** and **Send** in the recording bar.
- LFM3 speech output via the same model/projector; auto-speak can be muted, and
  completed answers can be replayed.
- Speech language selection (English default, 18 LFM3 languages).
- Model hub with installed state and delete-to-free-storage.
- Conversation history persists on the phone and survives app restarts; when
  the model reloads, prior turns are re-fed so it keeps context. Voice and
  image turns are remembered as text placeholders — `🎤 Voice message` for
  audio, the typed caption (or `🖼 Image` when there is none) for images — not
  as re-sent media.
- The current model is unloaded when switching modes or leaving the screen;
  the transcript stays.

## Implementation notes

- `llamadart` provides the Dart/native llama.cpp binding. The app pins a fork:
  `https://github.com/hamishfromatech/llamadart`, ref `ae5684b` (branch
  `lfm3-tts`), which uses `llama_dart_tts_get_info_ext` / `init_ext` for
  LFM3-Audio and LFM3-Omni speech output.
- The `mmproj` carries the audio encoder, depthformer and LiquidCodec decoder.
- No Qwen TTS and no system TTS are used for voice replies.
- Streaming UI updates are throttled to ~30 fps; Markdown is parsed only after
  a reply completes.
- An inline `</think>` marker inside the text stream is split into the Thinking
  block; channel-only thinking is kept as-is.
- Transcripts are written to `<documents>/local_chat_history/<model-id>.json`
  after every completed or failed turn, on new chat, and on dispose (from a
  message snapshot, because the state notifier is already torn down).
- The model, not the app, owns generation; a single engine is used per mode and
  is disposed on switch/exit.

## Known limits

- **Video input** is supported by the LFM3-Omni model, but the current Dart
  binding rejects video parts. Video needs the native llama.cpp path.
- TTS exposes language but not the model's female/male voice choice yet.
- No agent tool execution in local mode; it is a chat/voice/vision surface, not
  the desktop coding agent.
- Phone performance (tokens/s, thermal behaviour, RAM headroom) is still being
  measured on physical devices.
- iOS is gated in v1: the entry points are hidden and the `/local*` routes
  render the gate screen. See *Platform support (v1)*.

## Building the APK

```bash
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The native runtime is fetched by the `llamadart` build hook on first build.
