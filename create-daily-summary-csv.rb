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
require_relative 'regexes'

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

num_questions = all_questions.length
summary[:date] = DATE_STR
summary[:num_questions] = num_questions
summary['os:win'] = 0 # initialize it here to make it the 3rd column
summary['os:win7'] = 0
summary['os:win8'] = 0
summary['os:win10'] = 0
summary['os:win11'] = 0
summary['os:macos'] = 0
summary['os:linux'] = 0
summary['os:unknown'] = 0
summary['m:unknown'] = 0
summary['t:unknown'] = 0
summary['av:unknown'] = 0
summary['uc:unknown'] = 0

TOPICS_EMOJI_ARRAY.each { |t| summary[t[:name]] = 0 }
USERCHROME_EMOJI_ARRAY.each { |uc| summary[uc[:name]] = 0 }
ANTIVIRUS_EMOJI_ARRAY.each { |av| summary[av[:name]] = 0 }
EMAIL_EMOJI_ARRAY.each { |m| summary[m[:name]] = 0 }

all_questions.each do |q|
  q = q.to_h
  logger.debug "question: #{q.ai}"
  summary[q[:os].split(';').last] += 1
  summary[q[:topic].split(';').last] += 1
  summary[q[:email_provider].split(';').last] += 1
  summary[q[:antivirus].split(';').last] += 1
  summary[q[:userchrome].split(';').last] += 1
  logger.debug "summary: #{summary})"
end

summary['os:win'] = summary['os:win7'] + summary['os:win8'] +
                    summary['os:win10'] + summary['os:win11']

rows = []
rows.push(summary)
Dir.chdir(YYYY.to_s) do
  headers = summary.keys
  CSV.open(OUTPUT_FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
    rows.each { |row_array| csv_object << row_array }
  end
end
