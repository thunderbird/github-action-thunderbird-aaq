#!/usr/bin/env ruby
# Implements issue #27: reconstruct the 2026-03-14 questions file, which the
# Kitsune list API cannot serve (HTTP 500 for the whole day under every
# ordering/page_size because one question breaks server-side serialization).
#
# Strategy: the day's window fetches fine when split around the poisoned
# question. Fetch the two surrounding sub-windows, recover the poisoned
# question(s) by id via the single-object endpoint, then apply the EXACT same
# flattening/UTC/filter/sort as get-tb-creator-answers-questions-for-arbitrary-
# time-period.rb and write the standard CSV. Run from the repo root; writes into
# 2026/. Afterwards run the answers script for 2026-03-14.
#
# Boundaries (determined by bisection, see #27):
#   W1 (pre-poison)  : created__gt 2026-03-13T23:59:59  created__lt 2026-03-14T10:07:30
#   W2 (post-poison) : created__gt 2026-03-14T10:30:00   created__lt 2026-03-15
#   poison id range  : (1570863, 1570874) -> scan 1570864..1570873

require 'rubygems'
require 'bundler/setup'
require 'typhoeus'
require 'json'
require 'time'
require 'csv'
require 'logger'
require_relative 'get-kitsune-response'

API_SLEEP = (ENV['AAQ_API_SLEEP'] || '10').to_f
logger = Logger.new($stderr)
logger.level = Logger::DEBUG

API = 'https://support.mozilla.org/api/2/question/'
DupKey = 'id'

# UTC day bounds (same as the main script's min_created_time / end_time)
min_created_time = Time.gm(2026, 3, 14)
end_time = Time.gm(2026, 3, 14, 23, 59, 59)

# ---- collect raw question objects -----------------------------------------
raw = {} # id => question hash (dedup)

def fetch_window(api, gt, lt, logger, raw)
  params = { format: 'json', product: 'thunderbird', created__gt: gt, created__lt: lt }
  url = api
  loop do
    resp = getKitsuneResponse(url, params, logger)
    raise "nil response for window #{gt}..#{lt}" if resp.nil?
    params = nil
    (resp['results'] || []).each { |q| raw[q['id']] = q }
    url = resp['next']
    break if url.nil?
    sleep API_SLEEP
  end
end

logger.debug 'fetching W1 (pre-poison)'
fetch_window(API, '2026-03-13T23:59:59', '2026-03-14T10:07:30', logger, raw)
sleep API_SLEEP
logger.debug 'fetching W2 (post-poison)'
fetch_window(API, '2026-03-14T10:30:00', '2026-3-15', logger, raw)

# recover poisoned question(s) by id (single-object endpoint serializes one row)
logger.debug 'scanning poison id range 1570864..1570873'
(1570864..1570873).each do |id|
  sleep API_SLEEP
  resp = getKitsuneResponse("#{API}#{id}/", { format: 'json' }, logger)
  next if resp.nil? || resp['id'].nil?
  next unless resp['product'] == 'thunderbird'
  c = Time.parse(resp['created']).utc
  next unless c.to_i >= min_created_time.to_i && c.to_i <= end_time.to_i
  logger.debug "  recovered poison id #{id} created #{resp['created']}"
  raw[resp['id']] = resp
end

logger.debug "collected #{raw.size} raw questions"

# ---- flatten EXACTLY like the main questions script -----------------------
leading_keys = %w[id created updated locale product title is_solved solution solved_by is_spam
                  last_answer answers topic tags creator content]
csv = []
headers = []
raw.values.each do |q|
  created = Time.parse(q['created']).utc
  q['created'] = created.strftime('%Y-%m-%d %H:%M:%S %z')
  q['updated'] = Time.parse(q['updated']).utc.strftime('%Y-%m-%d %H:%M:%S %z') unless q['updated'].nil?

  q['tags'] = (q['tags'] || []).map { |t| "#{t['slug']};" }.join
  q['answers'] = (q['answers'] || []).map { |a| "#{a};" }.join
  q['creator'] = q['creator']['username']
  q['involved'] = (q['involved'] || []).map { |i| "#{i['username']};" }.join
  q['metadata'] = (q['metadata'] || []).map { |m| ";#{m['name']}:#{m['value']}" }.join
  q['updated_by'] = q['updated_by']['username'] unless q['updated_by'].nil?
  q['solved_by'] = q['solved_by']['username'] unless q['solved_by'].nil?

  leading_pairs = q.slice(*leading_keys)
  remaining = q.reject { |k, _v| leading_keys.include?(k) }
  q = leading_pairs.merge(remaining)
  keys = q.keys
  headers = keys if keys.length > headers.length

  next unless created.to_i >= min_created_time.to_i && created.to_i <= end_time.to_i

  q['content'] = q['content'].tr("\n", ' ')
  csv.push(q)
end

csv.sort_by! { |row| row['created'].to_s }

FILENAME = '2026/2026-03-14-2026-03-14-thunderbird-creator-answers-desktop-all-locales.csv'
logger.debug "writing #{csv.length} rows to #{FILENAME}"
CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
  csv.each { |row| csv_object << row }
end
warn "DONE: #{csv.length} questions written to #{FILENAME}"
