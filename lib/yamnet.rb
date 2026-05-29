require "onnxruntime"
require "csv"

class YamNet
  Bucket = Data.define(:name, :emoji, :is_speech)

  BUCKETS = {
    speech:     Bucket.new(name: "Speech",     emoji: "🗣️",  is_speech: true),
    laughter:   Bucket.new(name: "Laughter",   emoji: "😂", is_speech: false),
    crying:     Bucket.new(name: "Crying",     emoji: "😭", is_speech: false),
    shouting:   Bucket.new(name: "Shouting",   emoji: "🗯️",  is_speech: true),
    whispering: Bucket.new(name: "Whispering", emoji: "🤫", is_speech: true),
    singing:    Bucket.new(name: "Singing",    emoji: "🎶", is_speech: false),
    applause:   Bucket.new(name: "Applause",   emoji: "👏", is_speech: false),
    cheering:   Bucket.new(name: "Cheering",   emoji: "🎉", is_speech: false),
    music:      Bucket.new(name: "Music",      emoji: "🎵", is_speech: false),
    silence:    Bucket.new(name: "Silence",    emoji: "🤫", is_speech: false),
    crowd:      Bucket.new(name: "Crowd",      emoji: "👥", is_speech: false),
    other:      Bucket.new(name: "Other",      emoji: "🔊", is_speech: false),
  }.freeze

  KEYWORD_BUCKETS = [
    [:laughter,   %w[laughter baby\ laughter giggle chuckle snicker]],
    [:crying,     %w[crying sobbing whimper wail]],
    [:shouting,   %w[shout screaming yell scream]],
    [:whispering, %w[whispering]],
    [:singing,    %w[singing choir chant humming beatboxing]],
    [:speech,     ["speech", "narration", "monologue", "conversation",
                   "male speech", "female speech", "child speech"]],
    [:applause,   %w[clapping finger\ snapping applause]],
    [:cheering,   %w[cheering whoop]],
    [:music,      ["music", "song", "guitar", "piano", "drum",
                   "musical instrument", "orchestra", "bass", "synthesizer",
                   "hip hop", "jazz", "rock", "pop", "electronic music",
                   "reggae", "blues", "folk music", "country", "flamenco",
                   "violin", "cello", "flute", "trumpet", "harmonica",
                   "organ", "banjo", "sitar", "ukulele", "mandolin"]],
    [:silence,    %w[silence]],
    [:crowd,      ["chatter", "hubbub", "crowd", "children shouting"]],
  ].freeze

  def initialize(model_path:, class_map_path:)
    @session = OnnxRuntime::InferenceSession.new(model_path)
    @input_name = @session.inputs.first[:name]
    @class_map = load_class_map(class_map_path)
    @bucket_cache = build_bucket_cache
  end

  def classify(float_samples)
    outputs = @session.run(nil, { @input_name => float_samples })
    avg_scores = average_frames(outputs[0])
    top_idx = avg_scores.each_index.max_by { |i| avg_scores[i] }

    {
      class_name: @class_map[top_idx] || "Unknown",
      score: avg_scores[top_idx],
      bucket: @bucket_cache[top_idx] || BUCKETS[:other],
    }
  end

  private

  def load_class_map(path)
    CSV.foreach(path, headers: true).each_with_object({}) do |row, map|
      map[row["index"].to_i] = row["display_name"]
    end
  end

  def build_bucket_cache
    @class_map.transform_values { |name| match_bucket(name.downcase) }
  end

  def match_bucket(name)
    KEYWORD_BUCKETS.each do |key, keywords|
      return BUCKETS[key] if keywords.any? { |kw| name.include?(kw) }
    end
    BUCKETS[:other]
  end

  def average_frames(scores)
    return scores.flatten if scores.length == 1

    num_classes = scores.first.length
    avg = Array.new(num_classes, 0.0)
    scores.each do |frame|
      frame.each_with_index { |val, i| avg[i] += val }
    end
    avg.map { |v| v / scores.length }
  end
end
