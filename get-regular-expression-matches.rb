#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'
require 'CSV'
require 'pry'
require 'facets/enumerable/find_yield'
require_relative 'regexes'
# require 'nokogiri'

def get_emojis_from_regex(emoji_regex, content, _logger)
  emoji_regex.find_yield({ emoji: UNKNOWN_EMOJI, matching_text: nil }) \
  { |er| { emoji: er[:emoji], matching_text: Regexp.last_match(1) } if content =~ er[:regex] }
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

DATE_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY, m: MM, d: DD)

question_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
question_str += '-thunderbird-creator-answers-desktop-all-locales.csv'
answer_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d-%<yyyy2>4.4d-%<mm2>2.2d-%<dd2>2.2d' # hardcoding fixme
answer_str += '-thunderbird-answers-for-questions-desktop.csv'
output_str = '%<yyyy1>4.4d-%<mm1>2.2d-%<dd1>2.2d' # hardcoding fixme
output_str += '-thunderbird-regex-matches.csv'
OUTPUT_FILENAME = format(
  output_str,
  yyyy1: YYYY, mm1: MM, dd1: DD
)
logger.debug("output_filename: #{OUTPUT_FILENAME}")
all_questions = []
all_answers = []

# regex row is:
# id, os, topics, emailprovider, antivirus, userchrome
# 192535, windows11, install, fastmail, norton, ?
Dir.chdir(YYYY.to_s) do
  question_filename = format(question_str, yyyy1: YYYY, mm1: MM, dd1: DD, yyyy2: YYYY, mm2: MM, dd2: DD)
  answer_filename = format(answer_str, yyyy1: YYYY, mm1: MM, dd1: DD, yyyy2: YYYY, mm2: MM, dd2: DD)
  all_questions = CSV.read(question_filename, headers: true)
  all_answers = CSV.read(answer_filename, headers: true)
end

# See https://github.com/rtanglao/rt-tb-noto-emoji-2023/blob/main/create-emoji-question-graphics.rb
logger.debug "UNSORTED first id: #{all_questions[0]['id']}"
all_questions = all_questions.sort_by.with_index { |h, i| [h['id'], i] }
logger.debug "SORTED first id: #{all_questions[0]['id']}"

regular_expressions = []
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
  regular_expression_row = {
    id: id,
    date: DATE_STR,
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
