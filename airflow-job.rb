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
data = repositories.map do |repo|
  response = $codecov.get_single_branch(repo, branch)
  coverage = response.dig('commit', 'totals', 'c')
  {
    repository: repo,
    branch: branch,
    coverage: coverage,
    time: Time.now
  }
end.to_json

puts "#{data}"

if ENV.fetch('IS_DOCKER', false)
  File.open('/airflow/xcom/return.json', 'w') do |file|
    file.puts data
  end
end

puts "Finished airflow-job execution for codecov-metrics"
