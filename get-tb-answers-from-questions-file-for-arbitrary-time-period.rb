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
require_relative 'get_questions_filename'

def get_answers(answer_id, url_params, csv, url, logger)
  url = "#{url}#{answer_id}/"
  answer = getKitsuneResponse(url, url_params, logger)
  if answer.nil?
    logger.debug "#{answer_id} NOT found. EXITING"
    return nil
  end

  logger.debug "url:#{url}"
  logger.debug "url_params:#{url_params}"
  logger.ap answer
  updated = answer['updated']
  created = answer['created']
  question_id = answer['question']
  logger.debug "created from API (Pacific time despite the Z): #{created}"
  # All times returned by the API are in PST not PDT and not UTC
  # All URL parameters for time are also in PST not UTC
  # See https://github.com/mozilla/kitsune/issues/3961 and
  # https://github.com/mozilla/kitsune/issues/3946
  # The above may change in the future if we migrate the Kitsune database to UTC

  created = kludge_time_from_bogusZ_to_utc(answer['created'])
  logger.debug "created with PST correction: #{created}"

  unless updated.nil?
    logger.debug "updated from API (Pacific time despite the Z): #{updated}"
    updated = kludge_time_from_bogusZ_to_utc(answer['updated'])
    logger.debug "updated with PST correction: #{updated}"
  end
  id = answer['id']
  logger.debug "ANSWER id: #{id}"
  creator = answer['creator']['username']
  logger.debug "creator: #{creator}"
  csv.push([id, question_id, created.to_s, updated.to_s,
            answer['content'].tr("\n", ' '), creator, answer['is_spam'],
            answer['num_helpful_votes'],
            answer['num_unhelpful_votes']])
  logger.debug "PUSHED to csv. csv: #{csv}"
end

logger = Logger.new($stderr)
logger.level = Logger::DEBUG
if ARGV.length < 6
  puts "usage: #{$PROGRAM_NAME} yyyy mm dd end-yyyy mm dd"
  exit
end

questions_filename = get_questions_filename(
  ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i, ARGV[3].to_i,
  ARGV[4].to_i, ARGV[5].to_i
)
@dataTable = CSV.table(questions_filename)
answer_ids = @dataTable[:answers]
answer_ids = answer_ids.map { |s| "#{s}" }.join('')
logger.debug "answer_ids #{answer_ids}"

api_url = 'https://support.mozilla.org/api/2/answer/'
csv = []
url_params = {
  format: 'json',
  ordering: 'created'
}
answer_ids.split(';').each do |answer_id|
  num_answers = get_answers(answer_id, url_params, csv, api_url, logger)
  if num_answers.nil?
    logger.debug("answer: #{answer_id} NOT found!")
  else
    logger.debug("answer: #{answer_id} found")
  end
  sleep(1) # otherwise you will be throttled
end

logger.debug "AFTER ALL ANSWERS retrieved, csv: #{csv}"
exit if csv.empty?

headers = %w[id question_id created updated content creator is_spam num_helpful num_unhelpful]
fn_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d'
fn_str += '-thunderbird-answers-for-questions-desktop.csv'
FILENAME = format(fn_str,
                  yyyy1: ARGV[0].to_i, mm1: ARGV[1].to_i, dd1: ARGV[2].to_i,
                  yyyy2: ARGV[3].to_i, mm2: ARGV[4].to_i, dd2: ARGV[5].to_i)
logger.debug "CSV isn't empty, creating new version of #{FILENAME}"
CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
  csv.each { |row_array| csv_object << row_array }
end
