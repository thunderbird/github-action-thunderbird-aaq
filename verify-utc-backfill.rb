#!/usr/bin/env ruby
# Verification harness for backfill-utc-timestamps.rb (kept for historical
# purposes / re-runnable audit).
#
# For each sampled file it applies the SAME decision the backfill uses (fix iff
# the file's last git commit >= SWITCH instant), computes the resulting first-row
# `created`, and compares it to API ground truth at SECOND precision (CSVs store
# whole seconds; the API returns microseconds). Covers boundary cases: pre/post
# switch, old-dated files re-scraped post-switch, and both file types (the
# answers endpoint is /api/2/answer/, questions /api/2/question/).
#
# NOTE: sleep 10s between API calls + long backoff; the SUMO API throttles hard.

require 'json'; require 'time'; require 'csv'; require 'open-uri'; require 'shellwords'
REPO   = __dir__
SWITCH = Time.parse('2026-02-19T16:15:01Z') # first corrupted automated commit
TS     = /\A(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) [+-]\d{4}\z/

# [type, date]  type: :q (questions) / :a (answers)
CASES = [
  [:q, '2026-01-10'], [:q, '2026-01-21'], [:q, '2026-02-10'], [:q, '2026-02-18'],
  [:q, '2026-02-19'], [:q, '2026-02-20'], [:q, '2026-03-15'], [:q, '2026-06-01'],
  [:a, '2026-01-15'], [:a, '2026-01-31'], [:a, '2026-06-01']
]

def path(type, date)
  suf = type == :q ? 'creator-answers-desktop-all-locales' : 'answers-for-questions-desktop'
  "#{REPO}/2026/#{date}-#{date}-thunderbird-#{suf}.csv"
end

def last_commit(file)
  out = `git -C #{REPO.shellescape} log -1 --format=%cI -- #{file.shellescape}`.strip
  out.empty? ? nil : Time.parse(out)
end

def first_row(file)
  CSV.foreach(file, headers: true) { |r| return r if r['id'] && r['created'] }
  nil
end

def api_created(type, id)
  ep = type == :q ? 'question' : 'answer'
  tries = 0
  begin
    JSON.parse(URI.open("https://support.mozilla.org/api/2/#{ep}/#{id}/?format=json", read_timeout: 30).read)['created']
  rescue OpenURI::HTTPError => e
    return :nf if e.io.status[0].to_i == 404
    (tries += 1) > 8 and raise
    warn '  backoff 90s'; sleep 90; retry
  rescue StandardError
    (tries += 1) > 8 and raise
    warn '  backoff 20s'; sleep 20; retry
  end
end

def sec(t) = Time.at(t.to_i).utc

all_ok = true
CASES.each do |type, date|
  f = path(type, date)
  (puts "#{date} #{type}: (no file)"; next) unless File.exist?(f)
  ct  = last_commit(f)
  fix = ct && ct >= SWITCH
  row = first_row(f)
  id, stored = row['id'], row['created']
  api = api_created(type, id)
  (puts "#{date} #{type} id#{id}: API unavailable"; sleep 10; next) if api == :nf || api.nil?
  result = fix ? stored.sub(TS, '\1 +0000') : stored
  ok = sec(Time.parse(result)) == sec(Time.parse(api))
  all_ok &&= ok
  puts "#{date} #{type} id#{id}  [#{fix ? 'FIX ' : 'skip'}] commit=#{ct&.iso8601}"
  puts "    stored=#{stored.inspect}  ->result=#{Time.parse(result).utc}  truth=#{Time.parse(api).utc}  #{ok ? 'OK' : '*** MISMATCH ***'}"
  sleep 10
end
puts "\n#{all_ok ? 'ALL OK' : '*** MISMATCHES PRESENT ***'}"
