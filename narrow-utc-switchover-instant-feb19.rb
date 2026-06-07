#!/usr/bin/env ruby
# One-off investigation tool (kept for historical purposes).
#
# Third and final stage of pinning the Kitsune API's Pacific-as-Z -> true-UTC
# switchover. find-utc-switchover-date.rb / narrow-utc-switchover-day.rb worked
# off CURRENT file contents, which are misleading because corrupted re-scrapes
# overwrite earlier-correct files. The reliable signal is a FRESH "today"-file
# scrape: the file 2026/D-D-...creator...csv as-of an automated commit on UTC
# date D is a fresh API read at that commit's time.
#
# A coarse fresh-scrape bisect over all Feb-Jun commits localized the switch to
# 2026-02-19 (11:11:59Z correct, 16:15:01Z corrupted). This script bisects the
# fresh Feb-19 today-file across that day's commits to pin the instant to within
# one ~20-minute cron interval -- enough to classify every file by its last
# commit time for backfill-utc-timestamps.rb.
#
# NOTE: always sleep generously (10s) between API calls and back off long on
# 429s; the SUMO API throttles anonymous bursts hard.

require 'json'; require 'time'; require 'csv'; require 'open-uri'; require 'stringio'
REPO = __dir__
FILE = '2026/2026-02-19-2026-02-19-thunderbird-creator-answers-desktop-all-locales.csv'

commits = `cd #{REPO} && git log --format='%H %cI' --since='2026-02-19T11:00:00Z' --until='2026-02-19T16:30:00Z' --reverse`
          .lines.map { |l| l.split(' ', 2).map(&:strip) }.reject { |h, _| h.empty? }
puts "#{commits.length} Feb-19 commits in window"

def first_q(repo, commit, file)
  blob = `cd #{repo} && git show #{commit}:#{file} 2>/dev/null`
  return nil if blob.empty?
  CSV.new(StringIO.new(blob), headers: true).each { |r| return [r['id'], r['created']] if r['id'] && r['created'] }
  nil
end

def api_created(id)
  tries = 0
  begin
    JSON.parse(URI.open("https://support.mozilla.org/api/2/question/#{id}/?format=json", read_timeout: 30).read)['created']
  rescue OpenURI::HTTPError => e
    return :nf if e.io.status[0].to_i == 404
    (tries += 1) > 8 and raise
    warn '  backoff 90s'; sleep 90; retry
  rescue StandardError
    (tries += 1) > 8 and raise
    warn '  backoff 20s'; sleep 20; retry
  end
end

def corrupted?(commit, file)
  id, stored = first_q(REPO, commit, file)
  return nil if id.nil?
  api = api_created(id)
  return nil if api == :nf || api.nil?
  delta = ((Time.parse(stored).utc - Time.parse(api).utc) / 3600.0).round(2)
  sleep 10 # be gentle on the SUMO API
  [delta.abs >= 3, "q#{id} delta=#{delta}h"]
end

lo, hi = 0, commits.length - 1
while hi - lo > 1
  mid = (lo + hi) / 2
  c, t = commits[mid]
  res = corrupted?(c, FILE)
  if res.nil? then puts "#{t} #{c[0, 8]}: unusable"; lo = mid; next end
  bad, info = res
  puts "#{t} #{c[0, 8]}: #{bad ? 'CORRUPTED' : 'correct'} (#{info})"
  bad ? hi = mid : lo = mid
end
puts "\nlast correct  : #{commits[lo][1]} #{commits[lo][0][0, 8]}"
puts "first corrupt : #{commits[hi][1]} #{commits[hi][0][0, 8]}"
puts "==> SWITCH between #{commits[lo][1]} and #{commits[hi][1]}"
