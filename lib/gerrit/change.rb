require 'httparty'
require 'json'

require_relative 'base'

module Gerrit
  class Change
    include HTTParty
    base_uri "#{Gerrit.base_url}/changes"

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get(id)
      ret = self.class.get("/#{id}/detail", basic_auth: basic_auth).body.split("\n")
      parse_response(ret)
    end

    # Calling this param `account_id` to mirror the gerrit api docs.
    # From the docs an account id can be:
    # - a string of the format "Full Name <email@example.com>"
    # - just the email address ("email@example")
    # - a full name if it is unique ("Full Name")
    # - an account ID ("18419")
    # - a user name ("username")
    # - self for the calling user
    def add_reviewer(id:, account_id:)
      ret = self.class.post("/#{id}/reviewers",
        basic_auth: basic_auth,
        body: {
          reviewer: account_id
        }.to_json,
        headers: {
          'Content-Type' => 'application/json;charset=UTF-8'
        }
      ).body.split("\n")
      parse_response(ret)
    end

    private

    def basic_auth
      {
        username: @username,
        password: @password
      }
    end

    def parse_response(ret)
      # gerrit puts some weird cruft in the way at the top
      ret.shift
      JSON.parse(ret.join("\n"))
    end
  end
end
