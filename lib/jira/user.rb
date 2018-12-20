require 'httparty'
require 'json'

require_relative 'base'

module Jira
  class User
    include HTTParty
    base_uri "#{Jira.base_url}/user"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def search(username_or_name)
      JSON.parse(self.class.get(
        '/search',
        basic_auth: basic_auth,
        query: { 'username' => username_or_name },
        timeout: 5
      ).body)
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
