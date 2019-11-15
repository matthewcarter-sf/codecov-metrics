require 'nokogiri'

module Views
  class VelocityReport
    def initialize(reports)
      @reports = reports
    end

    def html
      builder = Nokogiri::HTML::Builder.new do |doc|
        doc.html {
          doc.body {
            doc.h2.bold {
              doc.text "Velocity Report"
            }
            doc.p.bold {
              doc.text "Week of #{Time.now.strftime("%m/%d/%Y")}"
            }
            @reports.each do |report|
              doc.hr
              doc.h3.bold.underline {
                doc.text "#{report['board'][:display_name]}"
              }
              doc.hr
              doc.a(target: '_blank', href: "https://scalefactor.atlassian.net/secure/RapidBoard.jspa?rapidView=#{report['board'][:id]}&view=reporting&chart=velocityChart") {
                doc.h4.normal(style: 'text-decoration: underline') {
                  doc.text "Historical Velocities"
                }
              }
              doc.table(width: '100%') {
                doc.thead {
                  doc.tr {
                    doc.th(style: "text-align: left") {
                      doc.text "Sprint"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Start"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "End"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Committed"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Completed"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Diff"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Attainment"
                    }
                  }
                }
                doc.tbody {
                  report['velocities'].each do |data|
                    doc.tr {
                      doc.td {
                        doc.text "#{data['sprint']['name']}"
                      }
                      doc.td {
                        doc.text "#{Date.parse(data['sprint']["startDate"]).strftime("%m/%d/%Y")}"
                      }
                      doc.td {
                        doc.text "#{Date.parse(data['sprint']["endDate"]).strftime("%m/%d/%Y")}"
                      }
                      doc.td {
                        doc.text "#{data['velocity']['estimated']['text']}"
                      }
                      doc.td {
                        doc.text "#{data['velocity']['completed']['text']}"
                      }
                      doc.td {
                        doc.text "#{data['velocity']['diff']['text']}"
                      }
                      doc.td {
                        doc.text "#{data['velocity']['attainment']['text']}"
                      }
                    }
                  end
                }
              }
              doc.a(target: '_blank', href: "https://scalefactor.atlassian.net/secure/RapidBoard.jspa?rapidView=#{report['board'][:id]}") {
                doc.h4.normal(style: 'text-decoration: underline') {
                  doc.text "Active Sprints"
                }
              }
              doc.table(width: '100%') {
                doc.thead {
                  doc.tr {
                    doc.th(style: "text-align: left") {
                      doc.text "Sprint"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Start"
                    }
                    doc.th(style: "text-align: left") {
                      doc.text "Points"
                    }
                  }
                }
                doc.tbody {
                  report['active'].each do |data|
                    doc.tr {
                      doc.td {
                        doc.text "#{data['sprint']['name']}"
                      }
                      doc.td {
                        doc.text "#{Date.parse(data['sprint']["startDate"]).strftime("%m/%d/%Y")}"
                      }
                      doc.td {
                        doc.text "#{data['points']}"
                      }
                    }
                  end
                }
              }
              doc.h4.normal(style: 'text-decoration: underline') {
                doc.text "Metrics"
              }
              doc.p.bold {
                doc.text "Avg attainment (non-zero committed): #{(('%.1f' % report['metrics']['average_attainment']) + '%')}"
              }
            end
          }
        }
      end
      builder.to_html
    end
  end
end
