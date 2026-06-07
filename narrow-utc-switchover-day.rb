#!/usr/bin/env ruby
# One-off investigation tool (kept for historical purposes).
#
# Companion to find-utc-switchover-date.rb, which localized the Kitsune API's
# Pacific-as-Z -> true-UTC switchover to between 2026-01-20 and 2026-02-05.
# This binary-searches the exact day, using as few API calls as possible.
#
# FINDING (run 2026-06-06): this day-granularity tool initially pointed at
# 2026-01-31, but that was MISLEADING -- it read the *current* Jan-31 file,
# which had been overwritten by a later corrupted re-scrape. Probing the
# freshly-scraped "today" file at each automated commit (see the commit-level
# bisect) showed the API actually switched to true UTC at 2026-02-01T15:24:51Z.
# From then on the old kludge_time_from_bogusZ_to_utc (removed 2026-06)
# corrupted created/updated by +8h (PST) / +7h (PDT). See fix-kludged-time.rb
# and backfill-utc-timestamps.rb.
#
# Method: a question's `created` is immutable, so the current API value is
# ground-truth UTC. Compare it to the stored CSV `created`:
#   delta ~ 0     -> scrape predates switch (kludge correct)
#   delta ~ 7/8h  -> scrape postdates switch (kludge corrupted it)
#
# NOTE: always sleep 5s between API calls and back off on rate-limit errors;
# the SUMO API throttles anonymous bursts.

require 'json'; require 'time'; require 'csv'; require 'open-uri'

REPO = __dir__
LO_DATE = '2026-01-20' # known correct
HI_DATE = '2026-02-05' # known corrupted

def first_q(date)
  f = "#{REPO}/2026/#{date}-#{date}-thunderbird-creator-answers-desktop-all-locales.csv"
  return nil unless File.exist?(f)
  CSV.foreach(f, headers: true) { |r| return [r['id'], r['created']] if r['id'] && r['created'] }
  nil
end

def fetch_created(id)
  tries = 0
  begin
    JSON.parse(URI.open("https://support.mozilla.org/api/2/question/#{id}/?format=json",
                        read_timeout: 30).read)['created']
  rescue OpenURI::HTTPError => e
    return :nf if e.io.status[0].to_i == 404
    (tries += 1) > 6 and raise
    warn "  q#{id} HTTP #{e.io.status[0]} backoff 60s (#{tries})"; sleep 60; retry
  rescue StandardError => e
    (tries += 1) > 6 and raise
    warn "  q#{id} #{e.class} backoff 15s (#{tries})"; sleep 15; retry
  end
end

# classify a date: :ok (pre-switch) / :bad (post-switch) / nil (unusable sample)
def classify(date)
  qc = first_q(date)
  return [nil, 'no file/row'] unless qc
  id, stored = qc
  api = fetch_created(id)
  return [nil, "q#{id} 404 — try another day"] if api == :nf
  return [nil, "q#{id} no created"] if api.nil?
  delta = ((Time.parse(stored).utc - Time.parse(api).utc) / 3600.0).round(2)
  sleep 5 # be gentle on the SUMO API
  [delta.abs < 3 ? :ok : :bad,
   "q#{id} delta=#{delta}h (stored=#{Time.parse(stored).utc} true=#{Time.parse(api).utc})"]
end

dates = Dir.glob("#{REPO}/2026/2026-*-thunderbird-creator-answers-desktop-all-locales.csv")
            .map { |f| File.basename(f)[/^\d{4}-\d{2}-\d{2}/] }
            .select { |d| d >= LO_DATE && d <= HI_DATE }.sort
lo, hi = 0, dates.length - 1 # dates[lo] known ok, dates[hi] known bad
puts "boundary is between #{dates[lo]} (ok) and #{dates[hi]} (bad)"
while hi - lo > 1
  mid = (lo + hi) / 2
  status, info = classify(dates[mid])
  puts "#{dates[mid]}: #{status} — #{info}"
  if status.nil? # unusable sample (404/missing) — probe a neighbour
    alt = mid + 1 < hi ? mid + 1 : mid - 1
    status, info = classify(dates[alt])
    puts "#{dates[alt]}: #{status} — #{info}"
    mid = alt
  end
  status == :ok ? lo = mid : hi = mid
end
puts "\n==> last correct day: #{dates[lo]}; first corrupted day: #{dates[hi]}"
