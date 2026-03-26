#!/usr/bin/env ruby
require 'rubygems'
require 'date'
require 'bundler/setup'
require 'amazing_print'
require 'logger'
logger = Logger.new(STDERR)
logger.level = Logger::DEBUG

if ARGV.length < 2
  puts "usage: #{$PROGRAM_NAME} yyyy mm"
  exit
end

# https://lite.datasette.io/?csv=https://github.com/thunderbird/github-action-thunderbird-aaq/blob/main/2026/2026-02-01-2026-02-01-thunderbird-creator-answers-desktop-all-locales.csv&csv=https://github.com/thunderbird/github-action-thunderbird-aaq/blob/main/2026/2026-02-02-2026-02-02-thunderbird-creator-answers-desktop-all-locales.csv#/data

year = ARGV[0].to_i
month = ARGV[1].to_i

start_date = Date.new(year, month, 1)

end_date = start_date >> 1 # >> 1 advances one month

datasette_url = 'https://lite.datasette.io/'
# Create a range from the start date up to (but not including) the end_date
(start_date...end_date).each_with_index do |date, index|
  date_str = date.strftime('%Y-%m-%d')
  questions_csv = "https://github.com/thunderbird/github-action-thunderbird-aaq/blob/main/#{year}/#{date_str}-#{date_str}-thunderbird-creator-answers-desktop-all-locales.csv"
  datasette_url += if index.zero?
                     "?csv=#{questions_csv}"
                   else
                     "&csv=#{questions_csv}"

                   end
end
puts 'copy/paste the following datasette_url into your web browser:'
puts datasette_url
