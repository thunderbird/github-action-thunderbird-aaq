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

def update_questions_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    question_str = '../get-tb-creator-answers-questions-for-arbitrary-time-period.rb '
    question_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    warn "question_str: #{question_str}"
    system(question_str)
  end
end

def update_answers_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    answer_str = '../get-tb-answers-from-questions-file-for-arbitrary-time-period.rb '
    answer_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    warn "answer_str: #{answer_str}"
    system(answer_str)
  end
end

if ARGV.length < 6
  puts "usage: #{$0} startyyyy startmm startdd endyyyy endmm enddd"
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

# metrics_row is:
# date, num_questions, response24, response48, response72
# 2023-04-01, 44, 0.50, 0.70, 0.80

question_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
question_str += '-thunderbird-creator-answers-desktop-all-locales.csv'
answer_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
answer_str += '-thunderbird-answers-for-questions-desktop.csv'

all_questions = []
all_answers = []

while current_date <= end_date
  num_questions = 0
  num24 = 0
  num48 = 0
  num72 = 0
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
    answers_for_this_question = all_answers.select { |a|
    a['question_id'] == question_id && a['creator'] != question_creator}
    answers_for_this_question.reverse_each do |a|
      answer_id = a['id']
      answer_created = a['created']
      answer_creator = a['creator']

      logger.debug "answer id: #{answer_id} answer created: #{answer_created} answer_creator: #{answer_creator}"
      answer_created_int = Time.parse(answer_created).to_i
      if answer_created_int < answered24
        num24 += 1
        num48 += 1
        num72 += 1
        logger.debug "question: #{question_id} answered within 24 hours"
      elsif answer_created_int < answered48
        num48 += 1
        num72 += 1
        logger.debug "question: #{question_id} answered within 48 hours"
      elsif answer_created < answered72
        num72 += 1
        logger.debug "question: #{question_id} answered within 48 hours"
      else
        logger.debug "question: #{question_id} NOT answered within 72 hours"
      end
      break
    end
  end
  current_date += 1
end
