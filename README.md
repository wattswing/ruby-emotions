# ruby_emotions

Real-time audio emotion detection from your microphone, powered by ONNX models running natively in Ruby.

```
┌────────────────────────────────────────────────┐
│                                                │
│  😊  HAPPY           █████████░░░░░░   62.1%   │
│  🗣️  Speech (87.3%)                            │
│                                                │
└────────────────────────────────────────────────┘
```

## How it works

A two-stage pipeline classifies live microphone audio every 0.75 seconds:

1. **YAMNet** (14MB) listens to the raw audio waveform and classifies the sound into categories: speech, laughter, music, applause, silence, etc.
2. **wav2vec2** (91MB, int8 quantized) runs on vocal audio to detect the speaker's emotion: happy, sad, angry, fear, disgust, or neutral.

Both stages combine to produce composite emotions — laughter + happy becomes "🤣 Hilarious!", whispering + fear becomes "😰 Terrified", and so on.

```
Audio ──► ffmpeg (mic capture) ──► ring buffer ──► YAMNet (sound type)
                                                        │
                                                   is vocal?
                                                   ├── yes ──► wav2vec2 (emotion) ──► composite label
                                                   └── no  ──► display bucket directly
```

## Requirements

- **Ruby** 3.2+
- **ffmpeg** (for microphone capture)

## Setup

```bash
git clone <repo-url> && cd ruby_emotions
./setup.sh
```

This downloads the ONNX models (~105MB total) and installs Ruby dependencies.

## Usage

```bash
ruby bin/ruby_emotions
```

The TUI displays the current detection in a box, with the 5 most recent detections below. Everything is centered and redraws in place — works well on large displays.

Press `Ctrl+C` to stop.

## Architecture

```
lib/
├── audio_capture.rb     # Streams mic audio via ffmpeg pipe, fills a ring buffer
├── audio_utils.rb       # PCM-to-float conversion, normalization
├── yamnet.rb            # YAMNet ONNX wrapper, maps 521 AudioSet classes to showcase buckets
├── emotion_detector.rb  # wav2vec2 SER wrapper, composite emotion logic
└── renderer.rb          # TUI rendering with box-drawing, centering, confidence bars
```

### Key design decisions

- **Sliding window**: a background thread continuously fills a 2-second ring buffer in 0.5s strides. The main thread samples the buffer every 0.75s for overlapping inference — smooth updates without blocking on capture.
- **ONNX Runtime**: both models run via [onnxruntime-ruby](https://github.com/ankane/onnxruntime-ruby) with plain Ruby arrays as input. No NumPy, no Python, no native ML framework required.
- **Piped audio**: a single persistent `ffmpeg` process streams raw 16-bit PCM to Ruby via `IO.popen`. No temp files, no disk I/O.
- **Bucket mapping**: YAMNet's 521 AudioSet classes are mapped to 12 curated buckets (speech, laughter, crying, shouting, music, etc.) via a keyword lookup cached at startup.
- **Composite emotions**: vocal signals from YAMNet combine with wav2vec2's base emotion to produce richer labels (e.g., shouting + angry = "🤬 Furious!").

### Models

| Model | Source | Input | Output |
|-------|--------|-------|--------|
| [YAMNet](https://huggingface.co/zeropointnine/yamnet-onnx) | TF → ONNX conversion | 1D float waveform (16kHz) | [frames, 521] class scores |
| [wav2vec2 SER](https://huggingface.co/onnx-community/wav2vec2-base-Speech_Emotion_Recognition-ONNX) | HuggingFace ONNX export (int8) | [batch, sequence] float (16kHz, normalized) | [batch, 6] emotion logits |

## Platform support

Audio capture auto-detects the platform:

| OS | ffmpeg input |
|----|-------------|
| macOS | `-f avfoundation -i ":default"` |
| Linux | `-f pulse -i default` (fallback: ALSA) |
| Windows | `-f dshow -i audio="Microphone"` |

## License

MIT
