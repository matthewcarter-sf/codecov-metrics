require 'sendgrid-ruby'

module Connectors
  class Sendgrid
    include SendGrid

    def initialize(api_key)
      @api_key = api_key
      @sg = SendGrid::API.new(api_key: @api_key)
    end

    def send(to, subject, html)
      payload = send_json_payload(to, subject, html)
      response = @sg.client.mail._("send").post(request_body: payload)
      response
    end

    private

      def send_json_payload(to, subject, html)
        {
          personalizations: [
            { 
              to: to.map { |email| { email: email } }
            }
          ],
          subject: subject,
          from: { 
            email: 'noreply@scalefactor.com',
            name: 'ScaleFactor'
          },
          content: [{
            type: 'text/html',
            value: html
          }]
        }
      end
  end
end