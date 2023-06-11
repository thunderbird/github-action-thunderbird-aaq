#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'typhoeus'
require 'amazing_print'
require 'json'
require 'time'
require 'date'
require 'csv'
require 'logger'
require 'pry'
require_relative 'get-kitsune-response'
require_relative 'fix-kludged-time'

logger = Logger.new(STDERR)
logger.level = Logger::DEBUG
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd end-yyyy mm dd"
  exit
end
# because of issue 3686, https://github.com/mozilla/kitsune/issues/3686,
# go back one day and forward one day
min_created_time = Time.gm(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i)
greater_than_time = (min_created_time - 3600 * 24).strftime('%Y-%-m-%-e')
less_than = Time.gm(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i)
end_time = Time.gm(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i, 23, 59, 59)

less_than_time = (less_than + 3600 * 24).strftime('%Y-%-m-%-e')
less_than_time_parsed = Time.parse(less_than_time + ' 00:00:00 UTC')
logger.debug "min_created_time #{min_created_time}"
logger.debug 'greater than time' + greater_than_time.to_s
logger.debug 'less than' + less_than.to_s
logger.debug 'less than time' + less_than_time.to_s

url_params = {
  format: 'json',
  product: 'thunderbird',
  created__gt: greater_than_time,
  created__lt: less_than_time,
  ordering: '+created'
}

url = 'https://support.mozilla.org/api/2/answer/'
end_program = false
answer_number = 0
csv = []
until end_program
  answers = getKitsuneResponse(url, url_params, logger)
  ap answers['results'][0]
  url_params = nil
  logger.debug "answer count:#{answers['count']}"
  url_params = nil
  created = ''
  answers['results'].each do |a|
    logger.ap a
    answer_number += 1
    logger.debug "ANSWER number:#{answer_number}"
    updated = a['updated']
    created = a['created']
    logger.debug "created from API (Pacific time despite the Z): #{created}" 
    # All times returned by the API are in PST not PDT and not UTC
    # All URL parameters for time are also in PST not UTC
    # See https://github.com/mozilla/kitsune/issues/3961 and
    # https://github.com/mozilla/kitsune/issues/3946
    # The above may change in the future if we migrate the Kitsune database to UTC

    created = kludge_time_from_bogusZ_to_utc(a['created'])
    logger.debug "created with PST correction: #{created}"

    unless updated.nil?
      logger.debug "updated from API (Pacific time despite the Z): #{updated}" 
      updated = kludge_time_from_bogusZ_to_utc(a['updated'])
      logger.debug "updated with PST correction: #{updated}"
    end
    id = a['id']
    logger.debug "ANSWER id: #{id}"
    logger.debug "ANSWER number: #{answer_number}"
    creator = a['creator']['username']
    logger.debug "createdtop: #{created.to_i}"
    logger.debug "min_created_time: #{min_created_time.to_i}"
    logger.debug "less_than_time_parsed: #{less_than_time_parsed.to_i}"
    logger.debug "creator: #{creator}"
    if created.to_i >= min_created_time.to_i && created.to_i <= end_time.to_i
      logger.debug 'NOT skipping'
      csv.push(
        [
          id, created.to_s, updated.to_s, a['title'], a['content'].tr("\n", ' '),
          creator, a['is_spam'], a['num_helpful_votes'], a['num_unhelpful_votes']
        ]
      )
    else
      logger.debug 'SKIPPING'
    end
  end
  url = answers['next']
  if url.nil?
    logger.debug 'nil next url'
  else
    logger.debug "next url:#{url}"
  end
  logger.debug "created: #{created.to_i}"
  logger.debug "min_created_time: #{min_created_time.to_i}"
  if (created.to_i < min_created_time.to_i) || url.nil?
    end_program = true
    break
  else
    sleep(1.0) # sleep 1 second between API calls
  end
end
exit if csv.empty?

headers = %w[id created updated title content creator is_spam num_helpful num_unhelpful]
fn_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d'
fn_str += '-thunderbird-answers-desktop.csv'
FILENAME = format(fn_str,
                  yyyy1: ARGV[0].to_i, mm1: ARGV[1].to_i, dd1: ARGV[2].to_i,
                  yyyy2: ARGV[3].to_i, mm2: ARGV[4].to_i, dd2: ARGV[5].to_i)
CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
  csv.each { |row_array| csv_object << row_array }
end
