require 'json'
require 'date'

module Reports
  # Returns velocity data for the last five closed
  # sprints, overall metric data for those sprints,
  # and the number sprint points committed in the 
  # currently active sprints
  class VelocityReport
    def initialize(jira)
      @jira = jira
    end

    def call(board)
      # Get all of the sprints
      sprints = @jira.list_sprints(board[:id])

      # Get the velocity reports
      sprint_velocities = @jira.list_velocities(board[:id])

      # Combine the full sprint information with the velocity report data
      velocity_data = sprint_velocities['velocityStatEntries'].map do |sprint_id, velocity|
        sprint = sprints.find do |sprint|
          sprint['id'].to_s == sprint_id
        end

        # Add the offset here for convenience
        estimated = velocity['estimated']['value']
        completed = velocity['completed']['value']

        diff = completed - estimated
        velocity['diff'] = { 'value' => diff, 'text' => diff.to_s }

        attainment = estimated == 0 ? 100.0 : (completed / estimated) * 100
        velocity['attainment'] = { 'value' => attainment, 'text' => (('%.1f' % attainment) + "%") }

        { 'sprint' => sprint, 'velocity' => velocity }
      end

      # Sort by sprint start date
      velocity_data = velocity_data.sort_by { |sprint| Date.parse(sprint['sprint']['startDate']) }

      # Pull some metrics based on the velocity data
      attainments = velocity_data.select { |data| data['velocity']['estimated']['value'] > 0 }.map do |data|
        data['velocity']['attainment']['value']
      end
      average_attainment = attainments.inject(0) { |sum, el| sum + (el || 0.0) }.to_f / attainments.size

      metrics_data = {
        'average_attainment' => average_attainment
      }

      # Filter out the active ones
      active_sprints = sprints.select do |sprint|
        sprint['state'] == 'active'
      end

      # Get the total number of active points
      active_sprint_data = active_sprints.map do |sprint|
        issues = @jira.list_issues(board[:id], sprint['id'])
        points = issues.inject(0) { |sum, issue| sum + (issue['fields'][Constants::Fields::STORY_POINTS_FIELD] || 0.0) }
        { 'sprint' => sprint, 'points' => points }
      end

      # Sort by sprint start date
      active_sprint_data = active_sprint_data.sort_by { |sprint| Date.parse(sprint['sprint']['startDate']) }

      {
        'board' => board,
        'velocities' => velocity_data,
        'active' => active_sprint_data,
        'metrics' => metrics_data
      }
    end
  end
end