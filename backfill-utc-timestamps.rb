#!/usr/bin/env ruby
# Backfill the timezone corruption caused by the old kludge running against the
# now-truthful-UTC Kitsune API (switchover 2026-02-19T~15:33-16:15Z; kludge
# removed 2026-06).
#
# The kludge kept the API's true-UTC wall-clock DIGITS and only relabeled the
# zone with a Pacific offset, so corrupted values look like
#   "2026-02-05 10:00:00 -0800"  (digits are true UTC; instant is +8h wrong)
# The fix is therefore purely local: keep the digits, set the zone to +0000.
# No API calls needed, and it exactly reproduces what re-scraping would yield.
#
# Safety: only files whose LAST git commit is at/after the switch instant are
# touched (so pre-switch files, which are in Pacific-offset format but hold the
# CORRECT instant, are left alone). This also correctly catches old-dated files
# that were re-scraped post-switch by the daily refresh. The transform is
# idempotent on rows already written as +0000 by the new code.
#
# Usage:  ./backfill-utc-timestamps.rb           # dry run (default)
#         ./backfill-utc-timestamps.rb --apply    # rewrite files in place

require 'csv'
require 'time'
require 'shellwords'

APPLY  = ARGV.include?('--apply')
REPO   = __dir__
SWITCH = Time.parse('2026-02-19T16:15:01Z') # first corrupted automated commit
TS     = /\A(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) [+-]\d{4}\z/ # "YYYY-MM-DD HH:MM:SS ±ZZZZ"
COLS   = %w[created updated].freeze

def last_commit_time(file)
  out = `git -C #{REPO.shellescape} log -1 --format=%cI -- #{file.shellescape}`.strip
  out.empty? ? nil : Time.parse(out)
end

files = Dir.glob("#{REPO}/2026/2026-*-thunderbird-creator-answers-desktop-all-locales.csv") +
        Dir.glob("#{REPO}/2026/2026-*-thunderbird-answers-for-questions-desktop.csv")
files.sort!

changed_files = 0
changed_cells = 0
skipped_preswitch = 0
samples = []

files.each do |f|
  ct = last_commit_time(f)
  if ct.nil? || ct < SWITCH
    skipped_preswitch += 1 unless ct.nil?
    next
  end
  table = CSV.read(f, headers: true)
  file_cells = 0
  table.each do |row|
    COLS.each do |c|
      v = row[c]
      next if v.nil?
      m = TS.match(v)
      next unless m
      fixed = "#{m[1]} +0000"
      next if fixed == v # already +0000 -> no-op (idempotent)
      samples << [File.basename(f), c, v, fixed] if samples.length < 8
      row[c] = fixed
      file_cells += 1
    end
  end
  next if file_cells.zero?
  changed_files += 1
  changed_cells += file_cells
  if APPLY
    File.write(f, table.to_csv)
  end
end

puts "mode            : #{APPLY ? 'APPLY (rewriting files)' : 'DRY RUN (no writes)'}"
puts "switch instant  : #{SWITCH.utc.iso8601}"
puts "files scanned   : #{files.length}"
puts "pre-switch skip : #{skipped_preswitch} (left untouched - already correct)"
puts "files to fix    : #{changed_files}"
puts "cells to fix    : #{changed_cells}"
puts "\nsample corrections (file | column | before -> after):"
samples.each { |b, c, before, after| puts "  #{b}  #{c}:  #{before}  ->  #{after}" }
puts "\n(dry run - rerun with --apply to write)" unless APPLY
