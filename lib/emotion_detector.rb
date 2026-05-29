require "onnxruntime"
require_relative "audio_utils"

class EmotionDetector
  Emotion = Data.define(:label, :emoji)

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

  def detect(float_samples, bucket_name: nil, speech_confidence: 1.0)
    if speech_confidence < SPEECH_CONFIDENCE_FLOOR
      return {
        emotion: NEUTRAL_EMOTION.label, emoji: NEUTRAL_EMOTION.emoji,
        confidence: speech_confidence, base_emotion: "NEUTRAL", composite: false,
      }
    end

    normalized = AudioUtils.normalize(float_samples)
    outputs = @session.run(nil, { @input_name => [normalized] })
    logits = outputs[0][0]

    probs = softmax(logits)
    top_idx = probs.each_index.max_by { |i| probs[i] }
    base_emotion = EMOTIONS[top_idx]

    composite = bucket_name && COMPOSITE[[bucket_name, base_emotion.label]]
    display = composite || base_emotion

    {
      emotion: display.label,
      emoji: display.emoji,
      confidence: probs[top_idx],
      base_emotion: base_emotion.label,
      composite: !!composite,
    }
  end

  private

  def softmax(logits)
    max = logits.max
    exps = logits.map { |l| Math.exp(l - max) }
    sum = exps.sum
    exps.map { |e| e / sum }
  end
end
