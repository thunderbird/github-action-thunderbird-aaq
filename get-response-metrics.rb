#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'
require 'CSV'

ONE_DAY_IN_SECONDS = 60 * 60 * 24
TWO_DAYS_IN_SECONDS = 2 * ONE_DAY_IN_SECONDS
THREE_DAYS_IN_SECONDS = 3 * ONE_DAY_IN_SECONDS

logger = Logger.new($stderr)
logger.level = Logger::DEBUG

if ARGV.length < 6
  puts "usage: #{$PROGRAM_NAME} startyyyy startmm startdd endyyyy endmm enddd"
  exit
end

START_YYYY = ARGV[0].to_i
START_MM = ARGV[1].to_i
START_DD = ARGV[2].to_i

END_YYYY = ARGV[3].to_i
END_MM = ARGV[4].to_i
END_DD = ARGV[5].to_i

current_date = Time.gm(START_YYYY, START_MM, START_DD).to_date
end_date = Time.gm(END_YYYY, END_MM, END_DD).to_date
logger.debug "current_date: #{current_date} end_date:#{end_date}"

question_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
question_str += '-thunderbird-creator-answers-desktop-all-locales.csv'
answer_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
answer_str += '-thunderbird-answers-for-questions-desktop.csv'
output_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
output_str += '-thunderbird-metrics.csv'
OUTPUT_FILENAME = format(
  output_str,
  yyyy1: START_YYYY, mm1: START_MM, dd1: START_DD,
  yyyy2: END_YYYY, mm2: END_MM, dd2: END_DD
)
all_questions = []
all_answers = []
metrics = []

# metrics_row is:
# date, num_questions, response24, response48, response72, not answered
# 2023-04-01, 44, 0.50, 0.70, 0.80, 0.10
date_format = '%<yyyy>4.4d-%<mm>2.2d-%<dd>2.2d'
while current_date <= end_date
  num_questions = 0
  num24 = 0
  num48 = 0
  num72 = 0
  num_not_answered = 0
  num_answered_after72 = 0
  y = current_date.year
  m = current_date.month
  d = current_date.day
  Dir.chdir(y.to_s) do
    question_filename = format(question_str, yyyy1: y, mm1: m, dd1: d, yyyy2: y, mm2: m, dd2: d)
    answer_filename = format(answer_str, yyyy1: y, mm1: m, dd1: d, yyyy2: y, mm2: m, dd2: d)
    all_questions = CSV.read(question_filename, headers: true)
    all_answers = CSV.read(answer_filename, headers: true)
  end
  all_questions.each do |q|
    num_questions += 1
    question_created = q['created']
    question_id = q['id']
    question_creator = q['creator']
    logger.debug "question id: #{question_id} question created: #{question_created}, question_creator: #{question_creator}"
    question_created_int = Time.parse(question_created).to_i
    answered24 = question_created_int + ONE_DAY_IN_SECONDS
    answered48 = question_created_int + TWO_DAYS_IN_SECONDS
    answered72 = question_created_int + THREE_DAYS_IN_SECONDS
    answers_for_this_question = all_answers.select do |a|
      a['question_id'] == question_id && a['creator'] != question_creator
    end
    if answers_for_this_question.empty?
      num_not_answered += 1
      logger.debug "question: #{question_id} NOT replied to at all."
      next
    end
    # FIXME: https://github.com/thunderbird/github-action-thunderbird-aaq/issues/3
    a = answers_for_this_question.reverse.first
    answer_id = a['id']
    answer_created = a['created']
    answer_creator = a['creator']

    logger.debug "answer id: #{answer_id} answer created: #{answer_created} answer_creator: #{answer_creator}"
    answer_created_int = Time.parse(answer_created).to_i
    if answer_created_int < answered24
      num24 += 1
      num48 += 1
      num72 += 1
      logger.debug "question: #{question_id} replied to within 24 hours."
    elsif answer_created_int < answered48
      num48 += 1
      num72 += 1
      logger.debug "question: #{question_id} replied to within 48 hours."
    elsif answer_created_int < answered72
      num72 += 1
      logger.debug "question: #{question_id} replied to within 72 hours."
    else
      num_answered_after72 += 1
      logger.debug "question: #{question_id} NOT replied to within 72 hours."
    end
  end
  # metrics_row is:
  # date, num_questions, response24, response48, response72, not answered
  # 2023-04-01, 44, 0.50, 0.70, 0.80, 0.10
  date_str = format(date_format, yyyy: y, mm: m, dd: d)
  metrics_row = {
    date: date_str,
    num_questions: num_questions,
    response24: num24.fdiv(num_questions),
    response48: num48.fdiv(num_questions),
    response72: num72.fdiv(num_questions),
    num_answered_after72: num_answered_after72.fdiv(num_questions),
    num_not_answered: num_not_answered.fdiv(num_questions)
  }
  logger.debug "metrics_row : #{metrics_row}"
  metrics.push(metrics_row)
  current_date += 1
end
Dir.chdir(START_YYYY.to_s) do
  headers = metrics[0].keys 
  CSV.open(OUTPUT_FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
    metrics.each { |row_array| csv_object << row_array }
  end
end
