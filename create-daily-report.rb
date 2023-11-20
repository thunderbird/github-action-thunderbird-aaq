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
DATE_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY, m: MM, d: DD) 
INPUT_FILENAME= "#{DATE_STR}-thunderbird-regex-matches.csv" # hardcoding fixme
OUTPUT_FILENAME= "#{DATE_STR}-thunderbird-daily-question-report.md" # hardcoding fixme

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

# Tooltips in markdown: https://stackoverflow.com/questions/49332718/is-it-possible-to-create-a-tool-tip-info-tip-or-hint-in-github-markdown
# [Hover your mouse here to see the tooltip](https://stackoverflow.com/a/71729464/11465149 "This is a tooltip :)")
# it works! see https://gist.github.com/rtanglao/3ec86f7680e712f8152594a880338538
exit
all_questions.each do |q|
  content = "#{q['title']} #{q['content']}"
  question_creator = q['creator']
  all_answers.each do |a|
    content += " #{a['content']}" if a['creator'] == question_creator
  end
  content += " #{q['tags']}"
  id = q['id']
  logger.debug "question id: #{id}"

  os_emoji_content = get_emojis_from_regex(OS_EMOJI_ARRAY, content, logger)
  topics_emoji_content = get_emojis_from_regex(TOPICS_EMOJI_ARRAY, q['tags'], logger)
  email_emoji_content = get_emojis_from_regex(EMAIL_EMOJI_ARRAY, content, logger)
  av_emoji_content = get_emojis_from_regex(ANTIVIRUS_EMOJI_ARRAY, content, logger)
  userchrome_emoji_content = get_emojis_from_regex(USERCHROME_EMOJI_ARRAY, content, logger)

  #  regular_expression_row is:
  #  id, date, title, os, topic, email, antivirus, userchrome
  #  128958, 2023-04-01, emoji;windows 10, emoji;fix-problems, emoji;outlook, emoji:avtext, emoji:userchrometext
  parsed_content = Nokogiri::HTML.parse(q['content']).text
  content_1st160 = "#{q['title']} #{parsed_content}"
  content_1st160 = content_1st160[0..159]
  regular_expression_row = {
    id: id,
    date: DATE_STR,
    content_1st160chars: content_1st160,
    os: "#{os_emoji_content[:emoji]};#{os_emoji_content[:matching_text]}",
    topic: "#{topics_emoji_content[:emoji]};#{topics_emoji_content[:matching_text]}",
    email_provider: "#{email_emoji_content[:emoji]};#{email_emoji_content[:matching_text]}",
    antivirus: "#{av_emoji_content[:emoji]};#{av_emoji_content[:matching_text]}",
    userchrome: "#{userchrome_emoji_content[:emoji]};#{userchrome_emoji_content[:matching_text]}"
  }
  logger.debug "regular_expression_row : #{regular_expression_row}"
  regular_expressions.push(regular_expression_row)
end
Dir.chdir(YYYY.to_s) do
  headers = regular_expressions[0].keys
  CSV.open(OUTPUT_FILENAME, 'w', write_headers: true, headers: headers) do |csv_object|
    regular_expressions.each { |row_array| csv_object << row_array }
  end
end
