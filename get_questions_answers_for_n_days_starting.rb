#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'

def update_questions_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    question_str = '../get-tb-creator-answers-questions-for-arbitrary-time-period.rb '
    question_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    logger.debug "question_str: #{question_str}"
    system(question_str)
  end
end

def update_answers_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    answer_str = '../get-tb-answers-from-questions-file-for-arbitrary-time-period.rb '
    answer_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    logger.debug "answer_str: #{answer_str}"
    system(answer_str)
  end
end

if ARGV.length < 4 || ARGV[3].to_i < 1
  puts "usage: #{$0} yyyy mm dd num_days"
  exit
end

YYYY = ARGV[0].to_i
MM = ARGV[1].to_i
DD = ARGV[2].to_i
NUM_DAYS = ARGV[3].to_i

current_date = Time.gm(YYYY, MM, DD).to_date
(NUM_DAYS + 1).times do
  y = current_date.year
  m = current_date.month
  d = current_date.day
  update_questions_for_yyyymmdd(y, m, d)
  update_answers_for_yyyymmdd(y, m, d)
  current_date += 1
end
