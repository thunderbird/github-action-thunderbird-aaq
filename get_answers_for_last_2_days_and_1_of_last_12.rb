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
    warn "question_str CLI: #{question_str}"
    system(question_str)
  end
end

def update_answers_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    answer_str = '../get-tb-answers-from-questions-file-for-arbitrary-time-period.rb '
    answer_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    warn "answer_str CLI: #{answer_str}"
    system(answer_str)
  end
end

COUNT_FILEPATH = '.answer_poll_count.txt'.freeze
if File.exist?(COUNT_FILEPATH)
  count = IO.readlines(COUNT_FILEPATH).map(&:to_i)[0]
  count += 1
else
  count = 1
end
File.open(COUNT_FILEPATH, 'w') { |f| f.write("#{count}\n") }

today = Time.now.utc.to_date
yesterday = today - 1

update_questions_for_yyyymmdd(today.year, today.month, today.day)
# update questions 50% of the time for yesterday
# update_questions_for_yyyymmdd(yesterday.year, yesterday.month, yesterday.day) if count % 2
# update answers for today and yesterday
update_answers_for_yyyymmdd(today.year, today.month, today.day)
# update_answers_for_yyyymmdd(yesterday.year, yesterday.month, yesterday.day)

day_to_refresh = today - ((count % 13) + 1)
# update questions for one of the other 13 days of the last two weeks
update_questions_for_yyyymmdd(day_to_refresh.year, day_to_refresh.month, day_to_refresh.day)
# update answers for the same day
update_answers_for_yyyymmdd(day_to_refresh.year, day_to_refresh.month, day_to_refresh.day)
