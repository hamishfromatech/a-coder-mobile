# On-device models

A-Coder Mobile can run LFM3 locally. No desktop bridge, no cloud, no network
after setup.

The on-device hub lives at **On-device** in the app (also reachable from the
pairing screen, the home memory icon and Settings). Omni is recommended.

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
  image turns are remembered as text placeholders ('Voice message', the image
  caption), not as re-sent media.
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
- iOS on-device support is not wired in this pass.

## Building the APK

```bash
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The native runtime is fetched by the `llamadart` build hook on first build.
