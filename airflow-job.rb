require 'dotenv/load'
require_relative 'connectors/codecov'

puts "Starting airflow-job execution for codecov-metrics"

reports = [
  { repo: 'client-services', branches: ['master'] },
  { repo: 'portal', branches: ['master'] },
  { repo: 'backoffice', branches: ['master'] }
]

$codecov = Connectors::Codecov.new

time = Time.now
data = {}

reports.each do |report|
  repo = report[:repo]
  data[repo] = report[:branches].map do |branch|
    puts "Requesting #{repo}-#{branch}"
    response = $codecov.get_single_branch(repo, branch)
    coverage = response.dig('commit', 'totals', 'c')
    {
      repository: repo,
      branch: branch,
      coverage: coverage,
      time: time
    }
  end
end

output_path = ENV.fetch('IS_DOCKER', false) ? '/airflow/xcom/return.json' : './return.json'

File.open(output_path, 'w') do |file|
  file.puts data.to_json
end

puts "Finished airflow-job execution for codecov-metrics"
