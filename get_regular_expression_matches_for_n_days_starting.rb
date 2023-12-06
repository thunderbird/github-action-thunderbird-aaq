#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'amazing_print'
require 'time'
require 'date'
require 'logger'
require 'pry'

def update_regex_matches_for_yyyymmdd(y, m, d)
  Dir.chdir(y.to_s) do
    regex_str = '../get-regular-expression-matches.rb '
    regex_str += "#{y} #{m} #{d} #{y} #{m} #{d}"
    warn "regex_str: #{regex_str}"
    system(regex_str)
  end
end

if ARGV.length < 4 || ARGV[3].to_i < 1
  puts "usage: #{$PROGRAM_NAME} yyyy mm dd num_days"
  exit
end

YYYY = ARGV[0].to_i
MM = ARGV[1].to_i
DD = ARGV[2].to_i
NUM_DAYS = ARGV[3].to_i

current_date = Time.gm(YYYY, MM, DD).to_date
(NUM_DAYS + 1).times do
  y = current_date.year
  m = current_date.month
  d = current_date.day
  update_regex_matches_for_yyyymmdd(y, m, d)
  current_date += 1
end
