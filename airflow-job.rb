require 'dotenv/load'
require_relative 'connectors/codecov'

puts "Starting airflow-job execution for codecov-metrics"

repositories = [
  'client-services',
  'portal',
  'backoffice'
]

$codecov = Connectors::Codecov.new

branch = 'master'
reports = repositories.each do |repo|
  response = $codecov.get_single_branch(repo, branch)
  coverage = response.dig('commit', 'totals', 'c')
  puts "#{repo} #{branch} coverage: #{coverage}%"
end

puts "Finished airflow-job execution for codecov-metrics"
