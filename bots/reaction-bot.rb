require 'slackbot_frd'

class ReactionBot < SlackbotFrd::Bot
  def channel_allowed?(channel)
    return false if channel =~ /linux/
    true
  end

  def add_callbacks(sc)
    sc.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if channel_allowed?(channel)
        post = ->(name) do
          sc.post_reaction(name: name, channel: channel, timestamp: timestamp)
        end

        any = ->(*reg) { reg.any?{ |r| message =~ r } }
        all = ->(*reg) { reg.all?{ |r| message =~ r } }

        begin
          post.call('nexy') if any.call(
            /(\s|^|:)nexy[,?!.:]*(\s|$)/i
          )

        rescue SlackbotFrd::AuthenticationFailedError => e
          if e.message =~ /already.reacted/i
            SlackbotFrd::Log.debug("Caught already_reacted exception: #{e.message}")
          else
            raise e
          end
        end
      end
    end
  end
end
