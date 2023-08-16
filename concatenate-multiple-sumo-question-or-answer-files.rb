#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'json'
require 'time'
require 'date'
require 'csv'
require 'logger'
require 'pry'
logger = Logger.new($stderr)
logger.level = Logger::DEBUG
if ARGV.length < 7
  puts "usage: #{$PROGRAM_NAME} yyyy mm dd end-yyyy end-mm end-dd <questions|answers>"
  exit
end
questions = true
questions_or_answers = ARGV[6]
if questions_or_answers != 'questions' && questions_or_answers != 'answers'
  puts "please enter 'questions' or 'answers'"
  exit
end
questions = false if questions_or_answers == 'answers'
YYYY1 = ARGV[0].to_i
MM1 = ARGV[1].to_i
DD1 = ARGV[2].to_i
START_DATE = Time.gm(YYYY1, MM1, DD1).to_date

YYYY2 = ARGV[3].to_i
MM2 = ARGV[4].to_i
DD2 = ARGV[5].to_i
OUTPUT_DIR = 'CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH'.freeze
output_file = "#{OUTPUT_DIR}/"
output_file += if questions
                 'thunderbird-desktop-questions-'
               else
                 'thunderbird-desktop-answers-'
               end
output_file +=
  format('%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d.csv',
         yyyy1: YYYY1, mm1: MM1, dd1: DD1,
         yyyy2: YYYY2, mm2: MM2, dd2: DD2)
END_DATE = Time.gm(YYYY2, MM2, DD2).to_date
NUMBER_OF_DAYS = (END_DATE - START_DATE).to_i + 1
current_date = START_DATE

files_str = ''
NUMBER_OF_DAYS.times do
  yyyy = current_date.year
  mm = current_date.month
  dd = current_date.mday
  fn_str = '%<yeard>4.4d/%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d'
  fn_str +=
    if questions
      '-thunderbird-creator-answers-desktop-all-locales.csv' # FIXME
    else
      '-thunderbird-answers-for-questions-desktop.csv' # FIXME
    end
  filename = format(
    fn_str,
    yeard: yyyy,
    yyyy1: yyyy, mm1: mm, dd1: dd,
    yyyy2: yyyy, mm2: mm, dd2: dd
  )
  files_str += "#{filename} "
  current_date += 1
end

# concat the csv files
command_line = 'mlr --csv cat then sort -n '
command_line += if questions
                  'id '
                else
                  'question_id '
                end
command_line += 'then put -f ./make-question-link.mlr '
command_line += "#{files_str} > #{output_file}"
system(command_line)
binding.pry

# if a CSV file doesn't exist, then exit
# add a link column
# sort by id (if there is a question_id field sort by question_id instead of id)
# write file to CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH
