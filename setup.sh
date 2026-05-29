#!/usr/bin/env bash
set -euo pipefail

MODELS_DIR="$(cd "$(dirname "$0")" && pwd)/models"
mkdir -p "$MODELS_DIR"

# Check ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "ERROR: ffmpeg is required but not found."
  echo "  macOS:   brew install ffmpeg"
  echo "  Linux:   sudo apt install ffmpeg"
  echo "  Windows: choco install ffmpeg"
  exit 1
fi

echo "ffmpeg found: $(ffmpeg -version | head -1)"

# Download YAMNet
if [ ! -f "$MODELS_DIR/yamnet.onnx" ]; then
  echo "Downloading YAMNet ONNX model (~14MB)..."
  curl -L -o "$MODELS_DIR/yamnet.onnx" \
    "https://huggingface.co/zeropointnine/yamnet-onnx/resolve/main/yamnet.onnx"
else
  echo "YAMNet model already downloaded."
fi

if [ ! -f "$MODELS_DIR/yamnet_class_map.csv" ]; then
  echo "Downloading YAMNet class map..."
  curl -L -o "$MODELS_DIR/yamnet_class_map.csv" \
    "https://huggingface.co/zeropointnine/yamnet-onnx/resolve/main/yamnet_class_map.csv"
else
  echo "YAMNet class map already downloaded."
fi

# Download wav2vec2 emotion recognition (int8 quantized)
if [ ! -f "$MODELS_DIR/wav2vec2_emotion_int8.onnx" ]; then
  echo "Downloading wav2vec2 emotion recognition model (~95MB)..."
  curl -L -o "$MODELS_DIR/wav2vec2_emotion_int8.onnx" \
    "https://huggingface.co/onnx-community/wav2vec2-base-Speech_Emotion_Recognition-ONNX/resolve/main/onnx/model_quantized.onnx"
else
  echo "wav2vec2 emotion model already downloaded."
fi

# Install Ruby dependencies
echo "Installing Ruby dependencies..."
BUNDLE_GEMFILE="$(cd "$(dirname "$0")" && pwd)/Gemfile" bundle install

echo ""
echo "Setup complete! Run: ruby bin/ruby_emotions"
