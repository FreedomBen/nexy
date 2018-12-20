require 'httparty'
require 'json'

require_relative 'base'
require_relative 'user'

module Jira
  class Issue
    include HTTParty
    base_uri "#{Jira.base_url}/issue"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      # curl -v https://mysite.atlassian.net --user me@example.com:my-api-token
      JSON.parse(self.class.get("/#{id}", basic_auth: basic_auth, timeout: 5).body)
    rescue JSON::ParserError => e
      { error: 'Jira returned invalid JSON (probably an error page in HTML :facepalm: )' }
    rescue StandardError => e
      { error: 'Unknown error occurred when querying Jira' }
    end

    def create(project:, issue_type:, summary:, description:, reporter_name: nil)
      JSON.parse(self.class.post('/', body: creation_hash(
        project: project,
        issue_type: issue_type,
        summary: summary,
        description: description,
        reporter_name: reporter_name
      ).to_json,
                                      basic_auth: basic_auth,
                                      headers: {
                                        'Content-Type' => 'application/json'
                                      },
                                      timeout: 5).body)
    end

    def set_reporter(issue_id, reporter); end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end

    def creation_hash(project:, issue_type:, summary:, description:, reporter_name: nil)
      retval = {
        fields: {
          project: {
            key: project
          },
          summary: summary,
          description: description,
          issuetype: {
            name: issue_type
          }
        }
      }
      if reporter_name
        retval[:fields][:reporter] = {}
        retval[:fields][:reporter][:name] = reporter_name
      end
      retval
    end
  end
end
