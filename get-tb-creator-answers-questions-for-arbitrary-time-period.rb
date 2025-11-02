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
require_relative 'get-kitsune-response'
require_relative 'fix-kludged-time'

def scalar?(variable)
  variable.is_a?(Numeric) || variable.is_a?(String) ||
    variable.is_a?(TrueClass) || variable.is_a?(FalseClass) ||
    variable.is_a?(NilClass)
end
logger = Logger.new(STDERR)
logger.level = Logger::DEBUG
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd end-yyyy mm dd"
  exit
end
# because of issue 3686, https://github.com/mozilla/kitsune/issues/3686,
# go back one day and forward one day
min_created_time = Time.gm(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i)
greater_than_time = (min_created_time - (3600 * 24)).strftime('%Y-%-m-%-e')
less_than = Time.gm(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i)
end_time = Time.gm(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i, 23, 59, 59)

less_than_time = (less_than + (3600 * 24)).strftime('%Y-%-m-%-e')
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
  ordering: 'created'
}

url = 'https://support.mozilla.org/api/2/question/'
end_program = false
question_number = 0
csv = []
headers = ''
until end_program
  questions = getKitsuneResponse(url, url_params, logger)
  if questions.nil?
    end_program = true
    next
  end
  url_params = nil
  logger.debug "question count:#{questions['count']}"
  url_params = nil
  created = ''
  known_non_scalars = %w[answers content creator involved metadata
                         tags updated_by]
  # move id,created,updated,title,content to beginning of hash
  leading_keys = %w[id created updated locale product title is_solved solution solved_by is_spam
                    last_answer answers topic tags creator content]
  questions['results'].each do |q|
    logger.ap q
    question_number += 1
    logger.debug "QUESTION number:#{question_number}"
    q.each_key do |k|
      unless scalar?(q[k])
        if known_non_scalars.include?(k)
          logger.debug("known non scalar: key:#{k} value:#{q[k].ai}")
        else
          logger.debug("WARNING unknown non scalar: key:#{k} value:#{q[k].ai}")
        end
      end
    end
    logger.debug "created from API: #{created} <-- this is PST not UTC despite the 'Z'"
    # All times returned by the API are in PST not PDT and not UTC
    # All URL parameters for time are also in PST not UTC
    # See https://github.com/mozilla/kitsune/issues/3961 and
    # https://github.com/mozilla/kitsune/issues/3946
    # The above may change in the future if we migrate the Kitsune database to UTC

    created = kludge_time_from_bogusZ_to_utc(q['created'])
    q['created'] = created.to_s
    logger.debug "created with PST correction: #{q['created']}"

    unless q['updated'].nil?
      logger.debug "updated from API: #{q['updated']} <-- this is PST not UTC despite the 'Z'"
      q['updated'] = kludge_time_from_bogusZ_to_utc(q['updated']).to_s
      logger.debug "updated with PST correction: #{q['updated']}"
    end
    id = q['id']
    logger.debug "QUESTION id: #{id}"
    logger.debug "QUESTION number: #{question_number}"
    tags = q['tags']
    tag_str = ''
    tags.each { |t| tag_str = tag_str + t['slug'] + ';' }
    q['tags'] = tag_str
    answers = q['answers']
    answers_str = ''
    answers.each { |a| answers_str = answers_str + a.to_s + ';' }
    q['answers'] = answers_str
    q['creator'] = q['creator']['username']
    # flatten involved, metadata
    involved_str = ''
    q['involved'].each { |i| involved_str = involved_str + i['username'] + ';' }
    q['involved'] = involved_str
    metadata_str = ''
    q['metadata'].each do |m|
      metadata_str =
        "#{metadata_str};#{m['name']}:#{m['value']}"
    end
    q['metadata'] = metadata_str
    logger.debug "createdtop: #{q['created'].to_i}"
    logger.debug "min_created_time: #{min_created_time.to_i}"
    logger.debug "less_than_time_parsed: #{less_than_time_parsed.to_i}"
    logger.debug "answers_str: #{answers_str}"
    logger.debug "creator: #{q['creator']}"
    logger.debug "question keys: #{q.keys.ai}"
    leading_pairs = q.slice(*leading_keys)
    remaining_pairs_pure_ruby = q.reject { |k, _v| leading_keys.include?(k) }
    reordered_hash = leading_pairs.merge(remaining_pairs_pure_ruby)
    logger.debug("reordered hash: #{reordered_hash.ai}")
    q = reordered_hash
    headers = q.keys if question_number == 1
    if created.to_i >= min_created_time.to_i && created.to_i <= end_time.to_i
      logger.debug 'NOT skipping'
      q['content'] = q['content'].tr("\n", ' ')
      logger.debug("pushing: #{q.ai}")
      csv.push(q)
    else
      logger.debug 'SKIPPING'
    end
  end
  url = questions['next']
  if url.nil?
    logger.debug 'nil next url'
  else
    logger.debug "next url:#{url}"
  end
  logger.debug "end_time: #{end_time.to_i}"
  if (created.to_i > end_time.to_i) || url.nil?
    end_program = true
    break
  else
    sleep(1) # sleep 1 second between API calls
  end
end
logger.debug "csv is empty for greater than: #{greater_than_time}  less than: #{less_than_time}" if csv.empty?
exit if csv.empty?

fn_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d'
fn_str += '-thunderbird-creator-answers-desktop-all-locales.csv'
FILENAME = format(fn_str,
                  yyyy1: ARGV[0].to_i, mm1: ARGV[1].to_i, dd1: ARGV[2].to_i,
                  yyyy2: ARGV[3].to_i, mm2: ARGV[4].to_i, dd2: ARGV[5].to_i)
# use the following code as a template, reuse the headers from the json response and flatten all non flat stuff like involved
logger.debug "headers: #{headers.ai}"
CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
  csv.each { |row_array| csv_object << row_array }
end
# CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
#  csv.each { |row_array| csv_object << row_array }
# end
