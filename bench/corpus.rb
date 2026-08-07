# frozen_string_literal: true

# Deterministic lorem corpus for FTS benchmarking.
# Both Turso (Tantivy) and SQLite FTS5 receive byte-identical content.
module Corpus
  WORDS = %w[
    database rails ruby sqlite turso activerecord migration model controller
    view routing cache session cookie validation callback association query
    index transaction locking connection pool adapter schema migration
    turbine engine blade rotor stator compressor generator power energy
    python javascript golang rust java kotlin swift scala elixir phoenix
    postgres mysql redis elasticsearch kubernetes docker aws azure gcp
    testing minitest rspec capybara fixture factory mock stub assertion
    performance benchmark latency throughput memory cpu disk network io
  ].freeze

  # Terms injected into a known fraction of rows for predictable query hit counts.
  SEARCHABLE = %w[database rails ruby turbine active record].freeze

  module_function

  # Returns an Array of {title:, body:} hashes, deterministic for a given count.
  def generate(count: 10_000, seed: 42)
    rng = Random.new(seed)
    Array.new(count) do |i|
      title = make_sentence(rng, 4..8)
      body = make_paragraph(rng, 30..80)
      # Inject a searchable term into ~30% of rows
      if rng.rand < 0.3
        term = SEARCHABLE[rng.rand(SEARCHABLE.size)]
        if rng.rand < 0.5
          title = "#{term} #{title}"
        else
          body = "#{body} #{term} #{term}"
        end
      end
      { title: title, body: body }
    end
  end

  def make_sentence(rng, word_range)
    n = word_range.min + rng.rand(word_range.max - word_range.min + 1)
    Array.new(n) { WORDS[rng.rand(WORDS.size)] }.join(" ").capitalize + "."
  end

  def make_paragraph(rng, word_range)
    sentences = 3 + rng.rand(5)
    Array.new(sentences) { make_sentence(rng, 8..20) }.join(" ")
  end
end
