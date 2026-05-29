module AudioUtils
  SAMPLE_RATE = 16_000
  BYTES_PER_SAMPLE = 2

  module_function

  def pcm_to_floats(raw_bytes)
    raw_bytes.unpack("s<*").map { |s| s / 32_768.0 }
  end

  def normalize(samples)
    n = samples.length.to_f
    sum = 0.0
    sum_sq = 0.0
    samples.each { |s| sum += s; sum_sq += s * s }
    mean = sum / n
    variance = (sum_sq / n - mean * mean).abs
    std = Math.sqrt(variance)
    return Array.new(samples.length, 0.0) if std < 1e-7

    samples.map { |s| (s - mean) / std }
  end

  def chunk_byte_size(duration:)
    (SAMPLE_RATE * BYTES_PER_SAMPLE * duration).to_i
  end
end
