require 'slackbot_frd'

class PasswordBot < SlackbotFrd::Bot

  def current_seconds
    Time.now.to_i
  end

  # Time between warnings
  def warning_wait_time_seconds
    1800
  end

  def recent_file
    '/tmp/nexy-password-recent.json'
  end

  def recent?(channel)
    current = JSON.parse(File.read(recent_file))
    if current[channel]
      return (current_seconds - current[channel]) < warning_wait_time_seconds
    else
      false
    end
  end

  def record_warning(channel)
    current = JSON.parse(File.read(recent_file))
    current[channel] = current_seconds
    File.write(recent_file, current.to_json)
  end

  def channel_enabled?(channel)
    return true
    %w[
      android-dev
      backend-guild
      borrower_team
      development
      loan_team
      mobilesquad
      nexus_team
      platform_team
      bot_testing
    ].include?(channel)
  end

  def user_sharing_password?(msg)
    msg =~ /(\s|^|:)password[,?!.:]*(\s|$)/i
  end

  def password_msg
    "Are you trying to share a password?\n\nIf so, please use one of these approved tools:\n- SN Private Bin: https://privatebin.simplenex.us/\n- Keybase.io\n\nMore info on Confluence:  https://simplenexus.atlassian.net/wiki/spaces/DEV/pages/954138834/Password+Sharing+at+SimpleNexus"
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user_sharing_password?(message) && channel_enabled?(channel) && user != :bot && user != 'nexy' && timestamp != thread_ts
        if recent?(channel)
          log_msg = "Password tripped, but not notifying again so soon in. User '#{user}' Channel '#{channel}'"
          SlackbotFrd::Log.info(log_msg)
          slack_connection.send_message(
            channel: 'nexy-log',
            message: log_msg
          )
        else
          log_msg = "Notifying user '#{user}' in channel '#{channel}' of potential password problem"
          record_warning(channel)
          SlackbotFrd::Log.info(log_msg)
          slack_connection.send_message(
            channel: channel,
            message: password_msg,
            thread_ts: thread_ts
          )
          slack_connection.send_message(
            channel: 'nexy-log',
            message: log_msg
          )
        end
      end
    end
    File.write(recent_file, '{}') unless File.exist?(recent_file)
  end
end
