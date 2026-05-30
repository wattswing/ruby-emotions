# frozen_string_literal: true

require_relative 'audio_utils'

# Captures audio from system microphone via ffmpeg
class AudioCapture
  attr_reader :window_duration, :stride

  SAMPLE_RATE = AudioUtils::SAMPLE_RATE
  DEFAULT_WINDOW = 2.0
  DEFAULT_STRIDE = 0.5

  def initialize(window: DEFAULT_WINDOW, stride: DEFAULT_STRIDE)
    @window_duration = window
    @stride = stride
    @window_samples = (SAMPLE_RATE * window).to_i
    @stride_bytes = AudioUtils.chunk_byte_size(duration: stride)
    @buffer = []
    @mutex = Mutex.new
    @process = nil
    @thread = nil
    @running = false
  end

  # Start audio capture in background thread
  def start
    ffmpeg_cmd = build_ffmpeg_command
    @process = IO.popen(ffmpeg_cmd, 'rb')
    @running = true
    @thread = Thread.new { capture_loop }
  end

  # Read current audio window samples
  def read_window
    @mutex.synchronize { @buffer.dup }
  end

  # Check if buffer has enough samples for a window
  def ready?
    @mutex.synchronize { @buffer.length >= @window_samples }
  end

  def stop
    @running = false
    @thread&.join(1)
    @thread = nil
    terminate_process
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
        trim_buffer_to_window
      end
    end
  end

  def trim_buffer_to_window
    overflow = @buffer.length - @window_samples
    @buffer.shift(overflow) if overflow.positive?
  end

  def build_ffmpeg_command
    [
      'ffmpeg', '-loglevel', 'quiet',
      *audio_input_args,
      '-ar', SAMPLE_RATE.to_s,
      '-ac', '1',
      '-f', 's16le',
      'pipe:1'
    ]
  end

  def audio_input_args
    case RUBY_PLATFORM
    when /darwin/
      %w[-f avfoundation -i :default]
    when /linux/
      pulse_audio? ? %w[-f pulse -i default] : %w[-f alsa -i default]
    when /mingw|mswin|cygwin/
      %w[-f dshow -i audio=Microphone]
    else
      raise "Unsupported platform: #{RUBY_PLATFORM}"
    end
  end

  def pulse_audio?
    system('pactl info >/dev/null 2>&1')
  end

  def terminate_process
    @process&.tap do |p|
      send_signal(p)
      close_process(p)
    end
  end

  def send_signal(process)
    Process.kill('TERM', process.pid)
  rescue StandardError
    nil
  end

  def close_process(process)
    process.close
  rescue StandardError
    nil
  end
end
