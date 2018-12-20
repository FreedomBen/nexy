require 'slackbot_frd'
require 'net/http'
require 'uri'

class DadjokeBot < SlackbotFrd::Bot
  def endpoint
    'https://icanhazdadjoke.com/'
  end

  def matches_channel?(channel)
    %w[bps_test_graveyard dadjokes general random watercooler].include?(channel)
  end

  def get_joke
    #   Net::HTTP.get_response(URI.parse(endpoint)).body
    `curl #{endpoint}`
  end

  def contains_trigger(message)
    message =~ /:dadjokes?:/i
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy' && matches_channel?(channel) && timestamp != thread_ts && contains_trigger(message)
        SlackbotFrd::Log.info("Fetching dad joke for user '#{user}' in channel '#{channel}'")
        slack_connection.send_message(
          channel: channel,
          message: get_joke,
          thread_ts: thread_ts,
          username: 'Dad Joke Bot',
          avatar_emoji: ':dadjokes:'
        )
      end
    end
  end
end
