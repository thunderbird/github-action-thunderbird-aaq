#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'
require 'CSV'
require 'fileutils'
require 'spark_pr'

logger = Logger.new($stderr)
logger.level = Logger::DEBUG

if ARGV.length < 7
  puts "usage: #{$PROGRAM_NAME} yyyy1 mm1 dd1 yyyy2 mm2 dd2 metric"
  exit
end

YYYY1 = ARGV[0].to_i
MM1 = ARGV[1].to_i
DD1 = ARGV[2].to_i
YYYY2 = ARGV[3].to_i
MM2 = ARGV[4].to_i
DD2 = ARGV[5].to_i
metric = ARGV[6]
metric_sym = metric.to_sym

# hardcoding fixme:
DATE1_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY1, m: MM1, d: DD1).freeze
DATE2_STR = format('%<y>4.4d-%<m>2.2d-%<d>2.2d', y: YYYY2, m: MM2, d: DD2).freeze

INPUT_FILENAME = 'ALLTIME/alltime-thunderbird-daily-summary.csv'.freeze # hardcoding fixme
OUTPUT_FILENAME = "#{DATE1_STR}-#{DATE2_STR}-#{metric}-thunderbird-sparkline.png".freeze # hardcoding fixme
SPARKLINE_PATH = "#{YYYY1}/reports/sparklines".freeze

logger.debug("INPUT_FILENAME: #{INPUT_FILENAME}")
logger.debug("OUTPUT_FILENAME: #{OUTPUT_FILENAME}")

all_daily_summaries = CSV.table('ALLTIME/alltime-thunderbird-daily-summary.csv', headers: true)
start_date = Date.new(YYYY1, MM1, DD1)
end_date = Date.new(YYYY2, MM2, DD2)
# https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
# Create directory if it doesn't exist
FileUtils.mkdir_p SPARKLINE_PATH
metrics = []
current_date = start_date
while current_date <= end_date
  logger.debug "curent_date: #{current_date}"
  metrics.push(all_daily_summaries.find { |s| s[:date] == current_date.to_s }[metric_sym].to_i)
  logger.debug "metric: #{metric}: #{metrics.last}"
  current_date += 1
end

Dir.chdir(SPARKLINE_PATH) do
  File.open(OUTPUT_FILENAME, 'wb') do |png|
    png << Spark.plot(
      metrics,
      type: 'smooth',
      has_min: true,
      has_max: true,
      has_last: true,
      height: 40,
      step: 10,
      normalize: 'logarithmic'
    )
  end
end
