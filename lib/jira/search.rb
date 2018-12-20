require 'httparty'
require 'json'

require_relative 'base'
require_relative 'user'

module Jira
  class Search
    include HTTParty
    base_uri "#{Jira.base_url}/search"
    GERRIT_ID_FIELD = "customfield_10403"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(jql)
      JSON.parse(self.class.get("/?fields=#{GERRIT_ID_FIELD},summary,assignee,priority&jql=#{jql}", basic_auth: basic_auth, timeout: 5).body)
    rescue JSON::ParserError => _e
      { error: 'Jira returned invalid JSON (probably an error page in HTML :facepalm: )' }
    rescue StandardError => _e
      { error: 'Unknown error occurred when querying Jira' }
    end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end
  end
end
