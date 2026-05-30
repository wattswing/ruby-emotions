# frozen_string_literal: true

# Audio processing utilities for ruby_emotions
module AudioUtils
  SAMPLE_RATE = 16_000
  BYTES_PER_SAMPLE = 2

  module_function

  def pcm_to_floats(raw_bytes)
    raw_bytes.unpack('s<*').map { |s| s / 32_768.0 }
  end

  def normalize(samples)
    mean = samples.sum / samples.length.to_f
    std = samples_std(samples, mean)
    return zero_array(samples) if std < 1e-7

    samples.map { |s| (s - mean) / std }
  end

  def chunk_byte_size(duration:)
    (SAMPLE_RATE * BYTES_PER_SAMPLE * duration).to_i
  end

  def samples_std(samples, mean)
    Math.sqrt(samples.sum { |s| (s - mean)**2 } / samples.length)
  end

  def zero_array(samples)
    Array.new(samples.length, 0.0)
  end
end
