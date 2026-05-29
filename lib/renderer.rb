# frozen_string_literal: true

require 'io/console'

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
    ratio = emotion ? emotion[:confidence] : result[:score]
    pct = (ratio * 100).round(1)
    "#{bar(ratio)}  #{pct.to_s.rjust(5)}%"
  end

  def format_sub(result)
    pct = (result[:score] * 100).round(1)
    "#{result[:bucket].emoji}  #{result[:class_name]} (#{pct}%)"
  end

  def render_current_box(result, emotion, w)
    top    = "┌#{'─' * BOX_INNER}┐"
    bottom = "└#{'─' * BOX_INNER}┘"
    blank  = "│#{' ' * BOX_INNER}│"

    unless result
      return [center(top, w), center("│#{'⏳  Waiting for audio...'.center(BOX_INNER)}│", w),
              center(bottom, w)]
    end

    row1 = "#{format_label(result, emotion)}  #{format_bar(result, emotion)}"
    sub  = format_sub(result)

    [
      center(top, w),
      center(blank, w),
      center("│  #{vpad(row1, BOX_INNER - 3)}│", w),
      center("│  #{vpad(sub, BOX_INNER - 3)}│", w),
      center(blank, w),
      center(bottom, w)
    ]
  end

  def render_history_cell(idx, result, emotion, w)
    cell_inner = BOX_INNER - 6
    label = format_label(result, emotion)
    ratio = emotion ? emotion[:confidence] : result[:score]
    pct = (ratio * 100).round(1)
    row1 = "#{label}  #{bar(ratio)}  #{pct.to_s.rjust(5)}%"
    sub  = format_sub(result)

    [
      center("#{idx}. ┌ #{vpad(row1, cell_inner)} ┐", w),
      center("   └ #{vpad(sub, cell_inner)} ┘", w)
    ]
  end

  def render(current_result, current_emotion, history)
    h, w = terminal_size
    separator = '═' * [BOX_INNER + 4, 40].max

    content = []
    content << center('🎤  ruby_emotions — Live Audio Sound Detection', w)
    content << center(separator, w)
    content << ''
    content.concat(render_current_box(current_result, current_emotion, w))
    content << ''

    if history.empty?
      content << center('(listening...)', w)
    else
      history.each_with_index do |(res, emo), i|
        content.concat(render_history_cell(i + 1, res, emo, w))
      end
    end

    content << ''
    content << center(separator, w)
    content << center('Ctrl+C to stop', w)

    top_pad = [(h - content.length) / 2, 0].max

    print "\e[H\e[J"
    top_pad.times { puts '' }
    puts content.join("\n")
    $stdout.flush
  end
end
