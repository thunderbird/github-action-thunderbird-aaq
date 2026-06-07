#!/usr/bin/env ruby
# Re-run the days that failed during the bulk Jan31->Jun6 re-scrape (questions
# came back empty during API 500 bursts, leaving stale files). For each day it
# re-runs the questions scrape then the answers scrape, waiting a RANDOM 2-10
# minutes between every command (per request, to avoid re-triggering throttling)
# and retrying each command up to 3 times. AAQ_API_SLEEP=10 keeps the per-call
# pacing gentle too.
#
# Usage:  ./rerun-failed-rescrape-days.rb [YYYY-MM-DD ...]
#         (no args -> the default incident list below)

require 'date'

REPO     = __dir__
YEAR_DIR = "#{REPO}/2026"
QSCRIPT  = '../get-tb-creator-answers-questions-for-arbitrary-time-period.rb'
ASCRIPT  = '../get-tb-answers-from-questions-file-for-arbitrary-time-period.rb'
MAX_TRIES = 3

ENV['AAQ_API_SLEEP'] ||= '10'
ENV['BUNDLE_GEMFILE'] = "#{REPO}/Gemfile"

DEFAULT_DAYS = %w[
  2026-02-08 2026-03-03 2026-03-12 2026-03-14 2026-03-15 2026-03-20
  2026-04-01 2026-04-02 2026-04-04 2026-04-06 2026-04-14 2026-04-15
  2026-04-16 2026-04-21 2026-04-30 2026-05-09 2026-05-11 2026-05-30
].freeze

days = (ARGV.empty? ? DEFAULT_DAYS : ARGV).map { |s| Date.parse(s) }
warn "re-running #{days.length} day(s) at AAQ_API_SLEEP=#{ENV['AAQ_API_SLEEP']}, random 2-10 min between commands"

def pace
  s = rand(120..600)
  warn "  [pace] sleeping #{s}s (~#{(s / 60.0).round(1)} min)  #{Time.now.utc.strftime('%H:%M:%SZ')}"
  sleep s
end

# returns :ok / :empty (hard fail) / :partial (answers: some questions skipped)
def run_cmd(kind, script, d)
  ymd = "#{d.year} #{d.month} #{d.day}"
  out = `cd #{YEAR_DIR} && bundle exec #{script} #{ymd} #{ymd} 2>&1`
  if kind == :q
    out.include?('QUESTIONS comand to re-run') ? :empty : :ok
  else
    return :empty   if out.include?('ANSWERS comand to re-run') && !out.include?('POSSIBLE')
    return :partial if out.include?('POSSIBLE ANSWERS comand to re-run')
    :ok
  end
end

def attempt(kind, script, d, first)
  MAX_TRIES.times do |i|
    pace unless first && i.zero?
    res = run_cmd(kind, script, d)
    warn "#{d} #{kind == :q ? 'questions' : 'answers '}: #{res} (try #{i + 1})"
    return res if res == :ok || res == :partial
  end
  :empty
end

hard_fail = []
partial   = []
first = true
days.each do |d|
  q = attempt(:q, QSCRIPT, d, first); first = false
  if q == :empty
    hard_fail << "#{d} (questions)"
    next # answers depend on questions; skip if questions still empty
  end
  a = attempt(:a, ASCRIPT, d, false)
  hard_fail << "#{d} (answers)" if a == :empty
  partial   << "#{d} (answers partial)" if a == :partial
end

warn "\n===== RE-RUN SUMMARY ====="
warn "still hard-failed: #{hard_fail.empty? ? 'none' : hard_fail.join(', ')}"
warn "answers partial  : #{partial.empty? ? 'none' : partial.join(', ')}"
