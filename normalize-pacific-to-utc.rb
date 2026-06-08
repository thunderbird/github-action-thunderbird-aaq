#!/usr/bin/env ruby
# Normalize pre-switch daily CSVs from Pacific-offset to UTC (+0000).
#
# Unlike backfill-utc-timestamps.rb (which RELABELED already-UTC digits), these
# files hold CORRECT instants in Pacific-offset representation, so this CONVERTS
# them: parse the offset-aware time and re-express it in UTC, preserving the
# instant. e.g. "2026-01-05 10:00:00 -0800" -> "2026-01-05 18:00:00 +0000".
# Only created/updated are touched. Idempotent on values already +0000.
#
# Usage:  ./normalize-pacific-to-utc.rb <file> [<file> ...]            # dry run
#         ./normalize-pacific-to-utc.rb --apply <file> [<file> ...]    # write

require 'csv'
require 'time'

APPLY = ARGV.delete('--apply')
TS    = /\A(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) [+-]\d{4}\z/
COLS  = %w[created updated].freeze

total_cells = 0
total_files = 0
samples = []

ARGV.each do |f|
  table = CSV.read(f, headers: true)
  cells = 0
  table.each do |row|
    COLS.each do |c|
      v = row[c]
      next if v.nil? || v.strip.empty?
      next unless TS.match(v)
      utc = Time.parse(v).utc.strftime('%Y-%m-%d %H:%M:%S %z')
      next if utc == v
      samples << [File.basename(f), c, v, utc] if samples.length < 8
      row[c] = utc
      cells += 1
    end
  end
  next if cells.zero?
  total_files += 1
  total_cells += cells
  File.write(f, table.to_csv) if APPLY
end

puts "mode        : #{APPLY ? 'APPLY (writing)' : 'DRY RUN'}"
puts "files given : #{ARGV.length}"
puts "files changed: #{total_files}"
puts "cells changed: #{total_cells}"
puts "\nsamples (file | col | before -> after):"
samples.each { |b, c, before, after| puts "  #{b}  #{c}:  #{before}  ->  #{after}" }
puts "\n(dry run - rerun with --apply to write)" unless APPLY
