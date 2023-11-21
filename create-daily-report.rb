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

logger = Logger.new($stderr)
logger.level = Logger::DEBUG

if ARGV.length < 3
  puts "usage: #{$PROGRAM_NAME} yyyy mm dd"
  exit
end

YYYY = ARGV[0].to_i
MM = ARGV[1].to_i
DD = ARGV[2].to_i

# hardcoding fixme:
DATE_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY, m: MM, d: DD).freeze
INPUT_FILENAME = "#{DATE_STR}-thunderbird-regex-matches.csv".freeze # hardcoding fixme
OUTPUT_FILENAME = "#{DATE_STR}-thunderbird-daily-question-report.md".freeze # hardcoding fixme

logger.debug("INPUT_FILENAME: #{INPUT_FILENAME}")
logger.debug("OUTPUT_FILENAME: #{OUTPUT_FILENAME}")

all_questions = []

# regex row is:
# id, os, topics, emailprovider, antivirus, userchrome
# 192535, windows11, install, fastmail, norton, ?
Dir.chdir(YYYY.to_s) do
  all_questions = CSV.read(INPUT_FILENAME, headers: true)
end

logger.debug "first question id: #{all_questions[0]['id']}"
logger.debug "LAST question id: #{all_questions[-1]['id']}"
# https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
# Create directory if it doesn't exist
FileUtils.mkdir_p "#{YYYY.to_s}/reports"


# Tooltips in markdown: https://stackoverflow.com/questions/49332718/is-it-possible-to-create-a-tool-tip-info-tip-or-hint-in-github-markdown
# [Hover your mouse here to see the tooltip](https://stackoverflow.com/a/71729464/11465149 "This is a tooltip :)")
# it works! see https://gist.github.com/rtanglao/3ec86f7680e712f8152594a880338538
exit



Dir.chdir(YYYY.to_s) do
  headers = regular_expressions[0].keys
  CSV.open(OUTPUT_FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
    regular_expressions.each { |row_array| csv_object << row_array }
  end
end
