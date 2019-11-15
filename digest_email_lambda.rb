require 'dotenv/load'
require_relative 'constants'
require_relative 'connectors/jira'
require_relative 'connectors/sendgrid'
require_relative 'reports/velocity_report'
require_relative 'views/velocity_report'

$jira = Connectors::Jira.new

report_boards = [
  Constants::Boards::ONBOARDING_CX,
  Constants::Boards::ONBOARDING_PROCESS,
  Constants::Boards::REPORTING,
  Constants::Boards::BOOKKEEPING,
  Constants::Boards::CARD,
  Constants::Boards::BILL_PAY
]

data = {}

reports = report_boards.map do |board|
  puts "Running on board #{board[:display_name]}"
  Reports::VelocityReport.new($jira).call(board)
end

html = Views::VelocityReport.new(reports).html

$sendgrid = Connectors::Sendgrid.new(ENV['SENDGRID_API_KEY'])
response = $sendgrid.send([
  'petermyers@scalefactor.com', 'matthewcarter@scalefactor.com'
], "Velocity Report", html)

reports.each do |report|
  data[report["board"][:name]] = report["velocities"].map do |v|
    if v["sprint"]["state"] == "closed"
      {
        "sprint_name": v["sprint"]["name"],
        "sprint_url": v["sprint"]["self"],
        "sprint_start_date": v["sprint"]["startDate"],
        "sprint_end_date": v["sprint"]["endDate"],
        "sprint_complete_date": v["sprint"]["completeDate"],
        "committed": v["velocity"]["estimated"]["value"],
        "delivered": v["velocity"]["completed"]["value"],
        "diff": v["velocity"]["diff"]["value"],
        "attainment": v["velocity"]["attainment"]["value"]
      }
    else
      nil
    end
  end.compact

  # Airflow specific xcom return
  if ENV.fetch('IS_DOCKER', false)
    File.open('/airflow/xcom/return.json', 'w') do |file|
      file.puts data.to_json
    end
  end
end
