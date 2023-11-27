#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'
require 'CSV'
require 'facets/enumerable/find_yield'
require 'fileutils'

def get_operating_system(os, summary)
  os = os.downcase
  emoji = os[0]
  case emoji
  when '🪟'
    summary[:win] += 1
    summary[:win7] += 1 if os =~ /;win[a-z\- ]*7/
    summary[:win8] += 1 if os =~ /;win[a-z\- ]*8/
    summary[:win10] += 1 if os =~ /;win[a-z\- ]*10/
    summary[:win11] += 1 if os =~ /;win[a-z\- ]*11/
  when '🍎'
    summary[:mac] += 1
  when '🐧'
    summary[:linux] += 1
  else
    summary[:unknown] += 1
  end
  summary
end

logger = Logger.new($stderr)
logger.level = Logger::DEBUG

if ARGV.length < 3
  puts "usage: #{$PROGRAM_NAME} yyyy mm dd"
  exit
end

YYYY = ARGV[0].to_i.freeze
MM = ARGV[1].to_i.freeze
DD = ARGV[2].to_i.freeze

# hardcoding fixme:
DATE_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY, m: MM, d: DD).freeze
INPUT_FILENAME = "#{DATE_STR}-thunderbird-regex-matches.csv".freeze # hardcoding fixme
OUTPUT_FILENAME = "#{DATE_STR}-thunderbird-daily-summary.csv".freeze # hardcoding fixme

logger.debug("INPUT_FILENAME: #{INPUT_FILENAME}")
logger.debug("OUTPUT_FILENAME: #{OUTPUT_FILENAME}")

all_questions = []

# regex row is:
# id, os, topics, emailprovider, antivirus, userchrome
# 192535, windows11, install, fastmail, norton, ?
Dir.chdir(YYYY.to_s) do
  unless File.exist?(INPUT_FILENAME)
    logger.debug "#{YYYY}/#{INPUT_FILENAME} doesn't exist, so exiting."
    exit
  end
  all_questions = CSV.read(INPUT_FILENAME, headers: true, header_converters: :symbol)
end


logger.debug "first question id: #{all_questions[0]['id']}"
logger.debug "LAST question id: #{all_questions[-1]['id']}"
summary = {}
summary[:os] = {}
summary[:os][:win] = 0
summary[:os][:win7] = 0
summary[:os][:win8] = 0
summary[:os][:win10] = 0
summary[:os][:win11] = 0
summary[:os][:mac] = 0
summary[:os][:linux] = 0
summary[:os][:unknown] = 0

all_questions.each do |q|
  q = q.to_h
  logger.debug "question: #{q.ai}"
  id = q[:id]
  summary[:os] = get_operating_system(q[:os], summary[:os])
  # markdown_str += "|#{format_emoji(q[:os])}"
  # markdown_str += "|#{format_emoji(q[:topic])}"
  # markdown_str += "|#{format_emoji(q[:email_provider])}"
  # markdown_str += "|#{format_emoji(q[:antivirus])}"
  # markdown_str += "|#{format_emoji(q[:userchrome])}"
  # markdown_str += "|#{format_tags(q[:tags])}|"
  logger.debug "summary: #{summary})"
  # summary.push(summary_row)
  binding.pry
end
exit
Dir.chdir(YYYY.to_s) do
  headers = summary[0].keys
  CSV.open(OUTPUT_FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
    summary.each { |row_array| csv_object << row_array }
  end
end
