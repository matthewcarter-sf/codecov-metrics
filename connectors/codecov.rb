require 'net/http'
require 'uri'
require 'json'
require 'date'

module Connectors
  class Codecov
    
    ROUTES = {
      get_single_branch: '/%{repo}/branch/%{branch}'
    }

    def initialize
      @owner = ENV.fetch('OWNER')
      @api_token = ENV.fetch('API_TOKEN')

      raise "Incomplete configuration. Ensure all envars are set: [OWNER, API_KEY]." unless @owner && @api_token

      @host = "https://codecov.io/api/gh/#{@owner}"
    end

    def get_single_branch(repo, branch)
      response = process_request(:get_single_branch, { repo: repo, branch: branch })
      response
    end

    private

      def process_request(uri_identifier, params = {})
        uri = construct_uri(uri_identifier, params)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request['Authorization'] = "token #{@api_token}"
        response_body = http.request(request).body
        JSON.parse(response_body)
      end

      def construct_uri(uri_identifier, params)
        uri = URI.parse(@host + (ROUTES[uri_identifier] % params))
        uri
      end
  end
end