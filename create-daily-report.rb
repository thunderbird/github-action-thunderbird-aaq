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
REPORTS_PATH = "#{YYYY}/reports".freeze

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

# https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
# Create directory if it doesn't exist
FileUtils.mkdir_p REPORTS_PATH
output_markdown = []
output_markdown.push(
  '|id      | date     |content                                                     | os | topic | email provider | antivirus | userChrome | tags|'
)
output_markdown.push(
  '|--------|----------|-------------------------------------------------------------|---|-------|----------------|-----------|------------|----|'
)

all_questions.each do |q|
  q = q.to_h
  logger.debug "question: #{q.ai}"
  id = q[:id]
  markdown_str = "|[#{id}](https://support.mozilla.org/questions/#{id})"
  markdown_str += "|#{q[:date]}"
  content = q[:content_1st160chars].gsub('|', '\|')
  content = content.gsub('[', '\[')
  content = content.gsub(']', '\]')
  content = content.gsub("'", "\'")

  truncated_content = content[0..65]
  # Tooltips in markdown: https://stackoverflow.com/questions/49332718/is-it-possible-to-create-a-tool-tip-info-tip-or-hint-in-github-markdown
  # [Hover your mouse here to see the tooltip](https://stackoverflow.com/a/71729464/11465149 "This is a tooltip :)")
  # it works! see https://gist.github.com/rtanglao/3ec86f7680e712f8152594a880338538
  markdown_str += "|[#{truncated_content}](## '#{content}')"
  markdown_str += "|#{q[:os]}"
  markdown_str += "|#{q[:topic]}"
  markdown_str += "|#{q[:email_provider]}"
  markdown_str += "|#{q[:antivirus]}"
  markdown_str += "|#{q[:userchrome]}"
  markdown_str += "|#{q[:tags]}|"
  logger.debug "markdown_str:#{markdown_str}"
  output_markdown.push(markdown_str)
end

Dir.chdir(REPORTS_PATH) do
  File.write(OUTPUT_FILENAME, output_markdown.join("\n"), mode: 'w')
end
