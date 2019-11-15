require 'dotenv/load'
require_relative 'connectors/jira'
require_relative 'constants'

# Assortment of useful Jira methods
class JiraUtils

  def initialize(jira)
    @jira = jira
  end

  # Returns the sprint ids for all active sprints
  # given a board id
  def find_active_sprints(board_id)
    sprints = @jira.list_sprints(board_id)
    sprints.select do |sprint|
      sprint['state'] == 'active'
    end
  end

  # Returns the sprint id for all active sprints
  # given a board id
  def find_last_closed_sprint(board_id)
    sprints = @jira.list_sprints(board_id)
    closed_sprints = sprints.select do |sprint|
      sprint['state'] == 'closed'
    end
    closed_sprints.sort_by do |sprint|
      Date.parse(sprint['endDate'])
    end
    closed_sprints.last
  end
end