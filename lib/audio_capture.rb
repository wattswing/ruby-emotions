require_relative "audio_utils"

class AudioCapture
  def initialize(window: 2.0, stride: 0.5)
    @window_samples = (AudioUtils::SAMPLE_RATE * window).to_i
    @stride_bytes = AudioUtils.chunk_byte_size(duration: stride)
    @buffer = []
    @mutex = Mutex.new
    @process = nil
    @thread = nil
    @running = false
  end

  def start
    cmd = [
      "ffmpeg", "-loglevel", "quiet",
      *platform_input_args,
      "-ar", AudioUtils::SAMPLE_RATE.to_s,
      "-ac", "1",
      "-f", "s16le",
      "pipe:1"
    ]
    @process = IO.popen(cmd, "rb")
    @running = true

    @thread = Thread.new { capture_loop }
  end

  def read_window
    @mutex.synchronize { @buffer.dup }
  end

  def ready?
    @mutex.synchronize { @buffer.length >= @window_samples }
  end

  def stop
    @running = false
    @thread&.join(1)
    @thread = nil
    @process&.tap do |p|
      Process.kill("TERM", p.pid) rescue nil
      p.close rescue nil
    end
    @process = nil
  end

  private

  def capture_loop
    while @running
      raw = @process.read(@stride_bytes)
      break if raw.nil? || raw.empty?

      samples = AudioUtils.pcm_to_floats(raw)
      @mutex.synchronize do
        @buffer.concat(samples)
        overflow = @buffer.length - @window_samples
        @buffer.shift(overflow) if overflow > 0
      end
    end
  end

  def platform_input_args
    case RUBY_PLATFORM
    when /darwin/  then ["-f", "avfoundation", "-i", ":default"]
    when /linux/   then pulse? ? ["-f", "pulse", "-i", "default"] : ["-f", "alsa", "-i", "default"]
    when /mingw|mswin|cygwin/ then ["-f", "dshow", "-i", "audio=Microphone"]
    else raise "Unsupported platform: #{RUBY_PLATFORM}. Provide ffmpeg input args manually."
    end
  end

  def pulse?
    system("pactl info >/dev/null 2>&1")
  end
end
