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

SPARKLINE_PATH = "#{YYYY}/reports/sparklines".freeze
# hardcoding fixme:
TODAY_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY, m: MM, d: DD).freeze
today = Date.new(YYYY, MM, DD)
yesterday = today - 1
six_days_ago = today - 6
six_days_ago_str = six_days_ago.strftime('%F')
seven_days_ago = today - 7
seven_days_ago_str = seven_days_ago.strftime('%F')
thirteen_days_ago = seven_days_ago - 6
thirteen_days_ago_str = thirteen_days_ago.strftime('%F')

logger.debug "THIS week: six days_ago:#{six_days_ago} UNTIL today: #{today}"
logger.debug "LAST week: 13 days ago: #{thirteen_days_ago} UNTIL seven days_ago:#{seven_days_ago}"

INPUT_FILENAME = "#{TODAY_STR}-thunderbird-regex-matches.csv".freeze # hardcoding fixme
OUTPUT_FILENAME = "#{TODAY_STR}-thunderbird-daily-question-report.md".freeze # hardcoding fixme
REPORTS_PATH = "#{YYYY}/reports".freeze

logger.debug("INPUT_FILENAME: #{INPUT_FILENAME}")
logger.debug("OUTPUT_FILENAME: #{OUTPUT_FILENAME}")

all_questions = []

Dir.chdir(YYYY.to_s) do
  unless File.exist?(INPUT_FILENAME)
    logger.debug "#{YYYY}/#{INPUT_FILENAME} doesn't exist, so exiting."
    exit
  end
  all_questions = CSV.read(INPUT_FILENAME, headers: true, header_converters: :symbol)
end

all_daily_summaries = CSV.table('ALLTIME/alltime-thunderbird-daily-summary.csv', converters: :all)
yesterday_str = (Time.gm(YYYY, MM, DD).to_date - 1).to_s

logger.debug "first question id: #{all_questions[0]['id']}"
logger.debug "LAST question id: #{all_questions[-1]['id']}"

# https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
# Create directory if it doesn't exist
FileUtils.mkdir_p REPORTS_PATH
output_markdown = []
output_markdown.push "**generated**: #{Time.now.strftime('%c %z')} "
output_markdown.push "## TODAY: #{today.strftime('%a, %B %e, %Y')}, compared to yesterday: \
#{yesterday.strftime('%a, %B %e, %Y')}, (UTC)"
output_markdown.push '### Questions'
num_today = all_questions.length
week1_counts = all_daily_summaries.select { |s| s[:date] >= six_days_ago && s[:date] <= today }
week1_average = week1_counts.sum { |day| day[:num_questions] }.to_f / week1_counts.size
week1_min, week1_max = week1_counts.minmax_by { |bb| bb[:num_questions]}.map{ |bb| bb[:num_questions] }
week2_counts = all_daily_summaries.select { |s| s[:date] >= thirteen_days_ago && s[:date] <= seven_days_ago }
week2_average = week2_counts.sum { |day| day[:num_questions] }.to_f / week2_counts.size
week2_min, week2_max = week2_counts.minmax_by { |bb| bb[:num_questions]}.map{ |bb| bb[:num_questions] }
# FIXME: above ^^^ b.minmax_by{ |bb| bb[:count]}.map{ |bb| bb[:count]}
num_yesterday = all_daily_summaries.find { |s| s[:date].to_date.to_s == yesterday_str }[:num_questions].to_f
percent_change = (((num_today - num_yesterday) / 100) * 100).round(1)
output_markdown.push "Yesterday: #{num_yesterday} Today: #{num_today} %change: #{percent_change} "
output_markdown.push "## THIS WEEK: #{six_days_ago.strftime('%a, %B %e, %Y')}-#{today.strftime('%a, %B %e, %Y')}, \
compared to LAST WEEK: #{thirteen_days_ago.strftime('%B %e, %Y')}-#{seven_days_ago.strftime('%B %e, %Y')}"

THIS_WEEK_SPARKLINE_FILENAME = "sparklines/#{six_days_ago_str}-#{TODAY_STR}-\
num_questions-thunderbird-sparkline.png".freeze # hardcoding fixme
LAST_WEEK_SPARKLINE_FILENAME = "sparklines/#{thirteen_days_ago_str}-#{seven_days_ago_str}-\
num_questions-thunderbird-sparkline.png".freeze # hardcoding fixme

logger.debug("sparkline path: #{SPARKLINE_PATH}")
logger.debug("THIS_WEEK_SPARKLINE_FILENAME: #{THIS_WEEK_SPARKLINE_FILENAME}")
logger.debug("LAST_WEEK_SPARKLINE_FILENAME: #{LAST_WEEK_SPARKLINE_FILENAME}")

output_markdown.push('### THIS WEEK')
output_markdown.push("**min**: #{week1_min} **max**: #{week1_max} **avg**: #{week1_average.round(1)}")
output_markdown.push("![This week](#{THIS_WEEK_SPARKLINE_FILENAME} '#{THIS_WEEK_SPARKLINE_FILENAME}')")

output_markdown.push('### LAST WEEK')
output_markdown.push("**min**: #{week2_min} **max**: #{week2_max} **avg**: #{week2_average.round(1)}")
output_markdown.push("![Last week](#{LAST_WEEK_SPARKLINE_FILENAME} '#{LAST_WEEK_SPARKLINE_FILENAME}')")

output_markdown.push "\n<details><summary>Click here for a detailed daily report</summary>\n"

output_markdown.push '## Detailed Report'
ID_HEADER_LENGTH = '001: 1234567'.length
ID_STR = 'id'.freeze
NBSP_STR = '&nbsp;'.freeze
DASH_STR = '-'.freeze
id_header = "#{ID_STR}#{NBSP_STR * (ID_HEADER_LENGTH - ID_STR.length)}"
header_string = "|#{id_header}"
TITLE_HEADER_LENGTH = 80
TITLE_STR = 'Title'.freeze
## FIXME: I don't know why github doesn't use a proportional font hence the '25' kludge
title_header = "#{TITLE_STR}#{NBSP_STR * ((TITLE_HEADER_LENGTH - TITLE_STR.length) + 25)}"
# title_header = "#{TITLE_STR}--#{NBSP_STR * ((TITLE_HEADER_LENGTH - TITLE_STR.length) + 0)}" <-- doesn't work
header_string += "|#{title_header}"
header_string += "|[O](## 'Operating System')|[T](## 'Topic')"
header_string += "|[M](## 'Email Provider')|[A](## 'Antivirus')"
header_string += "|[U](## 'User Chrome or other unsupported mod')"
header_string += "|[Tags](## 'All Tags')|"
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
output_markdown.push '</details>'
Dir.chdir(REPORTS_PATH) do
  File.write(OUTPUT_FILENAME, output_markdown.join("\n"), mode: 'w')
end
