#!/usr/bin/env ruby
# One-off investigation tool (kept for historical purposes).
#
# Detects WHEN the Kitsune API (support.mozilla.org/api/2) switched from
# returning Pacific wall-clock time mislabeled with a 'Z' suffix to returning
# truthful UTC. That switch made the old kludge_time_from_bogusZ_to_utc
# correction (see fix-kludged-time.rb, removed 2026-06) start corrupting data
# by +7h (PDT) / +8h (PST).
#
# Method: a question's `created` is immutable, so the CURRENT API value is the
# ground-truth UTC. For sampled historical question CSVs we compare:
#   stored CSV `created`  (= kludge(API-value-at-scrape-time))
#   vs current API `created` (= true UTC)
#   delta == 0     -> that scrape predates the switch (kludge was correct)
#   delta ~ +7/+8h -> that scrape postdates the switch (kludge corrupted it)
# The boundary month is the range that needs re-scraping/backfill.
#
# NOTE: always sleep 2s between API calls and back off on rate-limit errors;
# the SUMO API throttles anonymous bursts after ~7-10 rapid requests.

require 'json'
require 'time'
require 'csv'
require 'open-uri'

REPO = __dir__
SAMPLE_DAYS = [5, 20].freeze # ~2 samples per month

samples = []
Dir.glob("#{REPO}/20*/*-thunderbird-creator-answers-desktop-all-locales.csv").sort.each do |f|
  base = File.basename(f)
  next unless base =~ /^(\d{4})-(\d{2})-(\d{2})/
  samples << ["#{$1}-#{$2}", f] if SAMPLE_DAYS.include?($3.to_i)
end
puts "sampling #{samples.length} daily files"

def first_question(file)
  CSV.foreach(file, headers: true) do |r|
    return [r['id'], r['created']] if r['id'] && r['created']
  end
  nil
end

# Fetch with retry/backoff, mirroring get-kitsune-response.rb.
def fetch_created(id)
  tries = 0
  begin
    body = URI.open("https://support.mozilla.org/api/2/question/#{id}/?format=json",
                    read_timeout: 30).read
    JSON.parse(body)['created']
  rescue OpenURI::HTTPError => e
    return :not_found if e.io.status[0].to_i == 404
    tries += 1
    raise if tries > 5
    warn "  q#{id} HTTP #{e.io.status[0]}, backoff 60s (retry #{tries})"
    sleep 60
    retry
  rescue StandardError => e
    tries += 1
    raise if tries > 5
    warn "  q#{id} #{e.class}, backoff 10s (retry #{tries})"
    sleep 10
    retry
  end
end

results = []
samples.each do |ym, f|
  qc = first_question(f)
  next unless qc
  id, stored = qc
  begin
    api = fetch_created(id)
  rescue StandardError => e
    results << [ym, id, 'FETCH_FAIL', e.class.to_s]
    sleep 2
    next
  end
  if api == :not_found
    results << [ym, id, 'NOT_FOUND', 'question 404']
    sleep 2
    next
  end
  next if api.nil?

  stored_t = Time.parse(stored).utc
  true_t   = Time.parse(api).utc
  delta_h  = ((stored_t - true_t) / 3600.0).round(2)
  results << [ym, id, delta_h, "stored=#{stored_t} true=#{true_t}"]
  puts "#{ym}  q#{id}  delta=#{delta_h}h"
  $stdout.flush
  sleep 2 # be gentle on the SUMO API
end

puts "\n===== SUMMARY (delta hours: 0 = kludge correct, ~7/8 = kludge corrupting) ====="
results.each { |ym, id, d, info| puts format('%-8s q%-9s  %-8s  %s', ym, id, d, info) }
