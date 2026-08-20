#!/usr/bin/env ruby
# frozen_string_literal: true

# Reproduces the quantitative part of the conference-talk delivery audit.
# It reads temporary YouTube json3 caption files; it never stores or emits
# third-party transcript text.

require "json"

CAPTION_DIR = ARGV.fetch(0) do
  warn "usage: ruby scripts/analyze-conference-captions.rb CAPTION_DIR [SCRIPT] [CORPUS]"
  exit 64
end
SCRIPT_PATH = ARGV.fetch(1, "docs/talk/script.md")
CORPUS_PATH = ARGV.fetch(2, "docs/talk/delivery-audit.md")

MARKERS = {
  "audience" => ["you", "we", "let's"],
  "direction" => ["now", "next", "first", "second", "third", "here", "let's"],
  "demo cues" => ["look", "watch", "notice", "you can see", "here you can see", "let's see"],
  "qualification" => ["i think", "in this example", "for this", "depends", "roughly", "about"],
  "claim limits" => ["does not", "doesn't", "not a", "only", "within", "bounded"],
  "questions" => ["why", "what", "how", "when", "where", "who"]
}.freeze

def words(text)
  text.downcase.scan(/[\p{L}\p{N}]+(?:[’'][\p{L}\p{N}]+)*/)
end

def phrase_count(tokens, phrase)
  needle = words(phrase)
  return 0 if needle.empty? || tokens.length < needle.length

  tokens.each_cons(needle.length).count { |slice| slice == needle }
end

def marker_counts(tokens)
  MARKERS.to_h do |name, phrases|
    [name, phrases.sum { |phrase| phrase_count(tokens, phrase) }]
  end
end

def caption_text(path)
  document = JSON.parse(File.read(path))
  events = document.fetch("events", [])
  text = events.flat_map { |event| event.fetch("segs", []).map { |segment| segment["utf8"] } }.join(" ")
  text = text.gsub(/\[[^\]]+\]/, " ").gsub(">>", " ")

  last_ms = events.filter_map do |event|
    start = event["tStartMs"]
    start && start + event.fetch("dDurationMs", 0)
  end.max || 0

  [text, last_ms]
end

def corpus_ids(path)
  group = nil

  File.readlines(path).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |line, groups|
    group = "Goatmire" if line.start_with?("### Goatmire International")
    group = "ElixirConf" if line.start_with?("### ElixirConf comparison")
    match = line.match(%r{youtube\.com/watch\?v=([^\)]+)})
    groups[group] << match[1] if group && match
  end
end

def caption_path(directory, id)
  candidates = Dir.glob(File.join(directory, "#{id}.*.json3"))
  candidates.find { |path| path.include?("-orig.json3") } || candidates.first
end

def spoken_script(path)
  lines = File.readlines(path)
  start = lines.index { |line| line.start_with?("## 1 ·") }
  finish = lines.index { |line| line.start_with?("## Hard-cut map") }
  raise "could not find spoken script boundaries in #{path}" unless start && finish

  in_direction = false

  lines[(start + 1)...finish].filter_map do |line|
    stripped = line.strip

    if in_direction
      in_direction = false if stripped.end_with?(")*")
      next
    end

    if stripped.start_with?("*(")
      in_direction = !stripped.end_with?(")*")
      next
    end

    next if stripped.empty? || stripped.start_with?("#", "---")

    stripped.sub(/^\*\*CUT:\*\*\s*/, "")
  end.join(" ")
end

def summarize(label, documents)
  all_tokens = documents.flat_map { |document| document.fetch(:tokens) }
  duration_ms = documents.sum { |document| document.fetch(:duration_ms) }
  counts = marker_counts(all_tokens)

  {
    label: label,
    videos: documents.length,
    hours: duration_ms / 3_600_000.0,
    tokens: all_tokens.length,
    wpm: duration_ms.zero? ? nil : all_tokens.length / (duration_ms / 60_000.0),
    counts: counts,
    rates: counts.transform_values { |count| all_tokens.empty? ? 0 : count * 1000.0 / all_tokens.length }
  }
end

groups = corpus_ids(CORPUS_PATH)
missing = []

summaries = groups.map do |label, ids|
  documents = ids.filter_map do |id|
    path = caption_path(CAPTION_DIR, id)

    unless path
      missing << id
      next
    end

    text, duration_ms = caption_text(path)
    {tokens: words(text), duration_ms: duration_ms}
  end

  summarize(label, documents)
end

script_tokens = words(spoken_script(SCRIPT_PATH))
script_counts = marker_counts(script_tokens)
summaries << {
  label: "Stage script",
  videos: 1,
  hours: 0,
  tokens: script_tokens.length,
  wpm: nil,
  counts: script_counts,
  rates: script_counts.transform_values { |count| count * 1000.0 / script_tokens.length }
}

puts "| Corpus | Items | Hours | Spoken tokens | Audience | Direction | Demo cues | Qualification | Claim limits |"
puts "|---|---:|---:|---:|---:|---:|---:|---:|---:|"

summaries.each do |summary|
  rates = summary.fetch(:rates)
  puts format(
    "| %s | %d | %.1f | %d | %.2f | %.2f | %.2f | %.2f | %.2f |",
    summary.fetch(:label),
    summary.fetch(:videos),
    summary.fetch(:hours),
    summary.fetch(:tokens),
    rates.fetch("audience"),
    rates.fetch("direction"),
    rates.fetch("demo cues"),
    rates.fetch("qualification"),
    rates.fetch("claim limits")
  )
end

unless missing.empty?
  warn "missing captions for #{missing.length} video(s): #{missing.join(', ')}"
  exit 1
end
