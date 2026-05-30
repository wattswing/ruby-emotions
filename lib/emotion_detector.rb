# frozen_string_literal: true

require 'onnxruntime'
require_relative 'audio_utils'

# Detects emotions from audio samples using ONNX model
class EmotionDetector
  Emotion = Data.define(:label, :emoji)

  # Predefined emotion mappings with emoji icons
  EMOTIONS = {
    0 => Emotion.new(label: "SAD",     emoji: "😢"),
    1 => Emotion.new(label: "ANGRY",   emoji: "😠"),
    2 => Emotion.new(label: "DISGUST", emoji: "🤢"),
    3 => Emotion.new(label: "FEAR",    emoji: "😨"),
    4 => Emotion.new(label: "HAPPY",   emoji: "😊"),
    5 => Emotion.new(label: "NEUTRAL", emoji: "😐"),
  }.freeze

  NEUTRAL_EMOTION = Emotion.new(label: "NEUTRAL", emoji: "😐")
  SPEECH_CONFIDENCE_FLOOR = 0.5

  # Composite emotions for bucket + base emotion combinations
  COMPOSITE = {
    %w[laughter HAPPY]     => Emotion.new(label: "Hilarious!",  emoji: "🤣"),
    %w[laughter SAD]       => Emotion.new(label: "Bittersweet", emoji: "🥲"),
    %w[laughter NEUTRAL]   => Emotion.new(label: "Amused",      emoji: "😏"),
    %w[crying SAD]         => Emotion.new(label: "Devastated",  emoji: "😭"),
    %w[crying ANGRY]       => Emotion.new(label: "Frustrated",  emoji: "😤"),
    %w[crying FEAR]        => Emotion.new(label: "Distressed",  emoji: "😰"),
    %w[shouting ANGRY]     => Emotion.new(label: "Furious!",    emoji: "🤬"),
    %w[shouting HAPPY]     => Emotion.new(label: "Ecstatic!",   emoji: "🤩"),
    %w[shouting FEAR]      => Emotion.new(label: "Panicked!",   emoji: "😱"),
    %w[whispering FEAR]    => Emotion.new(label: "Terrified",   emoji: "😰"),
    %w[whispering SAD]     => Emotion.new(label: "Heartbroken", emoji: "💔"),
    %w[whispering NEUTRAL] => Emotion.new(label: "Secretive",   emoji: "🤫"),
    %w[whispering HAPPY]   => Emotion.new(label: "Flirty",      emoji: "😏"),
    %w[singing HAPPY]      => Emotion.new(label: "Joyful!",     emoji: "🎶"),
    %w[singing SAD]        => Emotion.new(label: "Melancholic", emoji: "🎵"),
    %w[singing NEUTRAL]    => Emotion.new(label: "Crooning",    emoji: "🎤"),
  }.freeze

  def initialize(model_path:)
    @session = OnnxRuntime::InferenceSession.new(model_path)
    @input_name = @session.inputs.first[:name]
  end

  # Detect emotion from audio samples with optional bucket classification
  def detect(float_samples, bucket_name: nil, speech_confidence: 1.0)
    return neutral_result(speech_confidence) if low_speech_confidence?(speech_confidence)

    logits = run_inference(float_samples)
    probs = softmax(logits)
    top_idx = find_top_emotion(probs)
    base_emotion = EMOTIONS[top_idx]

    composite_emotion = bucket_name ? composite_for(bucket_name, base_emotion.label) : nil
    display = composite_emotion || base_emotion

    result(probs, top_idx, base_emotion, composite_emotion, display)
  end

  private

  def neutral_result(confidence)
    {
      emotion: NEUTRAL_EMOTION.label,
      emoji: NEUTRAL_EMOTION.emoji,
      confidence: confidence,
      base_emotion: 'NEUTRAL',
      composite: false
    }
  end

  def low_speech_confidence?(confidence)
    confidence < SPEECH_CONFIDENCE_FLOOR
  end

  def run_inference(samples)
    normalized = AudioUtils.normalize(samples)
    outputs = @session.run(nil, { @input_name => [normalized] })
    outputs[0][0]
  end

  def softmax(logits)
    max = logits.max
    exps = logits.map { |l| Math.exp(l - max) }
    exps.sum.then { |sum| exps.map { |e| e / sum } }
  end

  def find_top_emotion(probs)
    probs.each_index.max_by { |i| probs[i] }
  end

  def composite_for(bucket, base)
    COMPOSITE[[bucket, base]]
  end

  def result(probs, top_idx, base_emotion, composite, display)
    {
      emotion: display.label,
      emoji: display.emoji,
      confidence: probs[top_idx],
      base_emotion: base_emotion.label,
      composite: !composite.nil?
    }
  end
end
