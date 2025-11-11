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

def get_answers(question_id, url_params, csv, url, logger)
  url_params[:question] = question_id
  end_fn = false
  answer_number = 0
  until end_fn
    answers = getKitsuneResponse(url, url_params, logger)
    if answers.nil?
      logger.debug "nil answers for question: #{question_id}. EXITING"
      return nil
    end

    logger.debug "url:#{url}"
    logger.debug "url_params:#{url_params}"
    logger.debug "answer count:#{answers['count']}"
    url_params = nil
    answers['results'].each do |a|
      logger.ap a
      answer_number += 1
      logger.debug "QUESTION: #{question_id} ANSWER number:#{answer_number}"
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
      logger.debug "creator: #{creator}"
      csv.push([id, question_id, created.to_s, updated.to_s,
                a['content'].tr("\n", ' '), creator, a['is_spam'],
                a['num_helpful_votes'],
                a['num_unhelpful_votes']])
    end
    url = answers['next']
    if url.nil?
      logger.debug 'nil next ANSWER url'
      end_fn = true
    else
      logger.debug "next ANSWER url:#{url}"
      sleep(1) # sleep 1 second between API calls
    end
  end
  answer_number
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
question_ids = @dataTable[:id]
logger.debug "question_ids #{question_ids}"

api_url = 'https://support.mozilla.org/api/2/answer/'
csv = []
url_params = {
  format: 'json',
  ordering: 'created'
}
question_ids.each do |question_id|
  num_answers = get_answers(question_id, url_params, csv, api_url, logger)
  if num_answers.nil?
    warn("question: #{question_id} has NO ANSWERS due to API exception! EXITING without updating answers.")
    exit
  else
    warn("question: #{question_id} has num_answers: #{num_answers}! UPDATING answers.")
  end
end

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
