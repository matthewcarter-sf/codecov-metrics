require 'dotenv/load'
require_relative 'connectors/codecov'

puts "Starting airflow-job execution for codecov-metrics"

$codecov = Connectors::Codecov.new
response = $codecov.get_single_branch('client-services', 'master')

puts "response: #{response.dig('commit', 'totals', 'c')}%"

puts "Finished airflow-job execution for codecov-metrics"
