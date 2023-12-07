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

def format_tags(tags_string_with_semicolons)
  tags = tags_string_with_semicolons.split(';')
  return "[❓](## 'No tags :-)')" if tags.empty?

  tags_str = ''
  tags.each do |t|
    tags_str += "[#{t}](https://support.mozilla.org/questions/thunderbird?tagged=#{t}&show=all), "
  end
  tags_str.chomp(', ')
end

def format_emoji(emoji_with_semicolon)
  if emoji_with_semicolon[0] == '❓'
    "[❓](## 'Troubleshooting details missing :-)')"
  else
    "[#{emoji_with_semicolon[0]}](## '#{emoji_with_semicolon.split(';').last}')"
  end
end
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
ID_HEADER_LENGTH = '001: 1234567'.length
ID_STR = 'id'.freeze
NBSP_STR = '&nbsp;'.freeze
DASH_STR = '-'
id_header = "#{ID_STR}#{NBSP_STR * (ID_HEADER_LENGTH - ID_STR.length)}"
header_string = "|#{id_header}"
TITLE_HEADER_LENGTH = 80
TITLE_STR = 'Title'.freeze
title_header = "#{TITLE_STR}#{NBSP_STR * ((TITLE_HEADER_LENGTH - TITLE_STR.length) + 1)}"
header_string = "|#{title_header}"
header_string += "|[O](## 'Operating System')|[T](## 'Topic')|[M](## 'Email Provider')|[A](## 'Antivirus')|[U](## 'User Chrome or other unsupported mod')|[Tags](## 'All Tags')|"
output_markdown.push(header_string)
EMOJI_HEADER_LENGTH = 1
TAGS_HEADER_LENGTH = 40
second_row_str =  "|#{DASH_STR * ID_HEADER_LENGTH}" # id
second_row_str += "|#{DASH_STR * TITLE_HEADER_LENGTH}" # content
second_row_str += "|#{DASH_STR * EMOJI_HEADER_LENGTH}" # OS
second_row_str += "|#{DASH_STR * EMOJI_HEADER_LENGTH}" # TOPIC
second_row_str += "|#{DASH_STR * EMOJI_HEADER_LENGTH}" # EMAIL PROVIDER
second_row_str += "|#{DASH_STR * EMOJI_HEADER_LENGTH}" # ANTI VIRUS
second_row_str += "|#{DASH_STR * EMOJI_HEADER_LENGTH}" # USERCHROME
second_row_str += "|#{DASH_STR * TAGS_HEADER_LENGTH}|" # TAGS
output_markdown.push(second_row_str)

all_questions.each.with_index(1) do |q, i|
  q = q.to_h
  logger.debug "question: #{q.ai}"
  id = q[:id]
  question_link_str = "https://support.mozilla.org/questions/#{id}"
  index = format('%3d', i)
  index = index.gsub(' ', '&nbsp;')
  markdown_str = "|#{index}:&nbsp;[#{id}](#{question_link_str} '#{q[:created]}')"
  # markdown_str += "|#{q[:date]}"
  content = q[:content_1st160chars].gsub('|', '\|')
  content = content.gsub('[', '\[')
  content = content.gsub(']', '\]')
  content = content.gsub("'", '&apos;')

  truncated_content = content[0..79]
  # Tooltips in markdown: https://stackoverflow.com/questions/49332718/is-it-possible-to-create-a-tool-tip-info-tip-or-hint-in-github-markdown
  # [Hover your mouse here to see the tooltip](https://stackoverflow.com/a/71729464/11465149 "This is a tooltip :)")
  # it works! see https://gist.github.com/rtanglao/3ec86f7680e712f8152594a880338538
  markdown_str += "|[#{truncated_content}](#{question_link_str} '#{content}')"
  markdown_str += "|#{format_emoji(q[:os])}"
  markdown_str += "|#{format_emoji(q[:topic])}"
  markdown_str += "|#{format_emoji(q[:email_provider])}"
  markdown_str += "|#{format_emoji(q[:antivirus])}"
  markdown_str += "|#{format_emoji(q[:userchrome])}"
  markdown_str += "|#{format_tags(q[:tags])}|"
  logger.debug "markdown_str:#{markdown_str})"
  output_markdown.push(markdown_str)
end

Dir.chdir(REPORTS_PATH) do
  File.write(OUTPUT_FILENAME, output_markdown.join("\n"), mode: 'w')
end
