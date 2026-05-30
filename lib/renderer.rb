# frozen_string_literal: true

require 'io/console'

# Renders audio emotion detection results to terminal
module Renderer
  BOX_INNER = 48
  BAR_WIDTH = 15
  LABEL_WIDTH = 14
  HISTORY_SIZE = 5

  module_function

  def terminal_size
    IO.console&.winsize || [24, 80]
  end

  def bar(ratio)
    filled = (ratio * BAR_WIDTH).round
    ('█' * filled) + ('░' * (BAR_WIDTH - filled))
  end

  def center(text, width)
    stripped = text.gsub(/\e\[[0-9;]*m/, '')
    pad = [(width - stripped.length) / 2, 0].max
    (' ' * pad) + text
  end

  def truncate(str, max)
    str.length > max ? "#{str[0...(max - 1)]}…" : str
  end

  def vpad(str, target)
    str + (' ' * [target - str.length, 0].max)
  end

  def format_label(result, emotion)
    if emotion
      "#{emotion[:emoji]}  #{truncate(emotion[:emotion], LABEL_WIDTH).ljust(LABEL_WIDTH)}"
    else
      "#{result[:bucket].emoji}  #{truncate(result[:bucket].name, LABEL_WIDTH).ljust(LABEL_WIDTH)}"
    end
  end

  def format_bar(result, emotion)
    ratio = confidence_ratio(result, emotion)
    pct = (ratio * 100).round(1)
    "#{bar(ratio)}  #{pct.to_s.rjust(5)}%"
  end

  # Use emotion confidence if available, otherwise use bucket score
  def confidence_ratio(result, emotion)
    emotion ? emotion[:confidence] : result[:score]
  end

  def format_sub(result)
    pct = (result[:score] * 100).round(1)
    "#{result[:bucket].emoji}  #{result[:class_name]} (#{pct}%)"
  end

  def render_current_box(result, emotion, width)
    return waiting_box_content(width) unless result

    build_box_lines(result, emotion, width)
      .map { |line| center(line, width) }
      .map { |line| "│#{line}│" }
      .map { |line| "  #{vpad(line, BOX_INNER - 3)}  " }
  end

  def build_box_lines(result, emotion, width)
    return waiting_box_content(width) if result.nil?

    [
      top_box_content,
      blank_line,
      row1_content(result, emotion),
      sub_content(result),
      blank_line,
      bottom_box_content
    ]
  end

  def waiting_box_content(_width)
    waiting = '⏳  Waiting for audio...'.center(BOX_INNER)
    [top_box_content, "│#{waiting}│", bottom_box_content]
  end

  def top_box_content
    "┌#{'─' * BOX_INNER}┐"
  end

  def bottom_box_content
    "└#{'─' * BOX_INNER}┘"
  end

  def blank_line
    "│#{' ' * BOX_INNER}│"
  end

  def row1_content(result, emotion)
    label = format_label(result, emotion)
    bar_line = format_bar(result, emotion)
    "#{label}  #{bar_line}"
  end

  def sub_content(result)
    format_sub(result)
  end

  def render_history_cell(index, result, emotion, width)
    cell = BOX_INNER - 6
    label = format_label(result, emotion)
    ratio = confidence_ratio(result, emotion)
    pct = (ratio * 100).round(1)
    row1 = "#{label}  #{bar(ratio)}  #{pct.to_s.rjust(5)}%"
    sub = format_sub(result)

    [
      center("#{index}. ┌ #{vpad(row1, cell)} ┐", width),
      center("   └ #{vpad(sub, cell)} ┘", width)
    ]
  end

  def render(current_result, current_emotion, history)
    height, width = terminal_size
    separator = '═' * [BOX_INNER + 4, 40].max

    content = render_content(separator, width, current_result, current_emotion, history)
    top_pad = [(height - content.length) / 2, 0].max

    print "\e[H\e[J"
    top_pad.times { puts '' }
    puts content.join("\n")
    $stdout.flush
  end

  def render_content(separator, width, current_result, current_emotion, history)
    build_header(separator, width) +
      build_current_box(width, current_result, current_emotion) +
      build_history_section(width, history) +
      build_footer(separator, width)
  end

  def build_header(separator, width)
    [
      center('🎤  ruby_emotions — Live Audio Sound Detection', width),
      center(separator, width),
      ''
    ]
  end

  def build_current_box(width, result, emotion)
    ['', render_current_box(result, emotion, width), '']
  end

  def build_history_section(width, history)
    if history.empty?
      [center('(listening...)', width)]
    else
      history_with_index = history.each_with_index.to_a
      history_with_index.flat_map do |(res, emo), i|
        render_history_cell(i + 1, res, emo, width)
      end
    end
  end

  def build_footer(separator, width)
    ['', center(separator, width), center('Ctrl+C to stop', width)]
  end
end
