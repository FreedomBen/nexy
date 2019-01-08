require 'slackbot_frd'

class PasswordBot < SlackbotFrd::Bot

  def channel_enabled?(channel)
    %w[systems_team bot_testing bps_test_graveyard].include?(channel)
  end

  def user_sharing_password?(msg)
    msg =~ /password/i
  end

  def password_msg
    'Are you trying to share a password?  Please read this before doing so:  https://simplenexus.atlassian.net/wiki/spaces/DEV/pages/954138834/Password+Sharing+at+SimpleNexus'
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user_sharing_password?(message) && channel_enabled?(channel) && user != :bot && user != 'nexy' && timestamp != thread_ts
        SlackbotFrd::Log.info("Notifying user of potential password problem")
        slack_connection.send_message(
          channel: channel,
          message: password_msg,
          thread_ts: thread_ts
        )
      end
    end
  end
end
