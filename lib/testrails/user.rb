require 'httparty'
require 'json'

require_relative 'base'

module Testrails
  class Change
    include HTTParty
    base_uri Testrails.base_url.to_s

    def initialize(username:, password:)
      @username = username
      @password = password
    end

    def get_testcase(id)
      ret = self.class.get("/get_case/#{id}", basic_auth: basic_auth,
                                              headers: {
                                                'Content-Type' => 'application/json'
                                              },
                                              timeout: 5)
      return "Error: #{ret.code}" if ret.code != 200
      ret = ret.body.split("\n")
      JSON.parse(ret.join("\n"))
    end

    def get_sections(section_id)
      breadcrumbs = ''
      current_id = section_id
      loop do
        ret = self.class.get("/get_section/#{current_id}", basic_auth: basic_auth,
                                                           headers: {
                                                             'Content-Type' => 'application/json'
                                                           },
                                                           timeout: 5).body.split("\n")
        result = JSON.parse(ret.join("\n"))
        breadcrumbs = ' > ' + result['name'] + breadcrumbs
        break if result['depth'] == 0
        current_id = result['parent_id']
      end
      breadcrumbs = breadcrumbs[3...breadcrumbs.length]
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
