require 'slackbot_frd'

class ScrabbleBot < SlackbotFrd::Bot
  def channel_allowed?(channel)
    #%w[bps_test_graveyard].include?(channel)
    true
  end

  def scrabblize(message)
    message.gsub(/^scrabbl(e|ize)/i, '').downcase.strip.chars.map do |ch|
      if ch =~ /^[a-z]$/
        ":scrabble-#{ch}:"
      elsif ch == ' '
        ':scrabble-blank:'
      else
        ch
      end
    end.join
  end

  def contains_trigger?(message)
    message =~ /^scrabbl(e|ize)/i
  end

  def add_callbacks(sc)
    sc.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy' && channel_allowed?(channel) && timestamp != thread_ts && contains_trigger?(message)
        sc.send_message(
          channel: channel,
          message: scrabblize(message),
          thread_ts: thread_ts,
          username: 'Scrabble Bot (Nexy)',
          avatar_emoji: ':scrabble-n:'
        )
      end
    end
  end
end
