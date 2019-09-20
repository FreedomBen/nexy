require 'slackbot_frd'
require 'net/http'
require 'uri'
require 'twilio-ruby'

class EmergencyBot < SlackbotFrd::Bot
  PINPOINT_SMS_VOICE_REGION = 'us-west-2'
  PINPOINT_ORIG_PHONE = '+17328120833'

  def destinations
    #  {
    #    ben: '+123456788',
    #    #justin: '+123456788',
    #  }
    JSON.parse(File.read('data/oncall.json'))
  end

  def matches_channel?(channel)
    %w[oncall on-call-testing].include?(channel)
  end

  def contains_trigger(message)
    # TODO: Might consider adding a sentinel value, either to indicate to send or not to send
    true
  end

  def sns
    @sns ||= Aws::SNS::Client.new(region: 'us-east-1')
    @sns
  end

  def pinpointsmsvoice
    @pinpointsmsvoice ||= Aws::PinpointSMSVoice::Client.new(region: 'us-east-1')
    @pinpointsmsvoice
  end

  def twilio
    @twilio ||= Twilio::REST::Client.new(
      $slackbotfrd_conf['twilio_account_sid'],
      $slackbotfrd_conf['twilio_auth_token']
    )
    @twilio
  end

  def send_sms_twilio(to:, message:)
    if to.empty?
      'skipped (no phone)'
    else
      twilio.messages.create(
        messaging_service_sid: $slackbotfrd_conf['twilio_messaging_service_sid'],
        to: to,
        body: message
      ).status
    end
  end

  def send_sms_sns(to:, message:)
    sns.publish(
      phone_number: to,
      message: message
    )
  end

  def send_sms(to:, message:)
    SlackbotFrd::Log.info("Sending SMS to '#{to}' message: '#{message}'")
    send_sms_twilio(to: to, message: message)
  end

  def make_phone_call_cli(to:, message:)
    puts 'making call with the cli'
    command = <<~EOF.gsub("\n", ' ')
      aws pinpoint-sms-voice send-voice-message
        --content '{"PlainTextMessage":{"LanguageCode":"en-US","Text":"#{message}"}}'
        --destination-phone-number '#{to}'
        --origination-phone-number '#{PINPOINT_ORIG_PHONE}'
        --region #{PINPOINT_SMS_VOICE_REGION}
    EOF
    puts "Running command: #{command}"
    `#{command}`
  end

  def make_phone_call(to:, message:)
    puts "Calling '#{to}'"
    resp = pinpointsmsvoice.send_voice_message({
      #caller_id: "Nexy (incident)",
      #caller_id: "Nexy",
      #configuration_set_name: "WordCharactersWithDelimiters",
      content: {
        plain_text_message: {
          language_code: "en-US",
          text: message,
          #voice_id: "String",
        },
      },
      origination_phone_number: PINPOINT_ORIG_PHONE,
      destination_phone_number: to,
      #origination_phone_number: "NonEmptyString",
    })
  rescue StandardError => e
    #puts e.backtrace.join("\n\t")
    SlackbotFrd::Log.error("Error making phone call with AWS pinpoint: #{e.message}")
  end

  def twilio_results_to_str(results)
    results
      .map { |result| "{'#{result.person}': '#{result.status}'}" }
      .join(",\n")
  end

  def destinations_for_channel(channel)
    case channel
    when 'on-call-testing'
      destinations.select{|k, v| k == 'bporter'}
    when 'oncall'
      destinations
    else
      {}
    end
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy' && matches_channel?(channel) && timestamp != thread_ts && contains_trigger(message)

        # Text/call the people
        #
        # Notify of success/failure in a thread under the message

        unless thread_ts    # We don't send thread messages to everybody
          SlackbotFrd::Log.info("Passing on Message '#{message}' to everyone from '#{user}'")

          msg = "SimpleNexus Alert in ##{channel} reported by '#{user}': #{message}"

          #slack_connection.send_message(
          #  channel: channel,
          #  message: "Sending a text message to: #{destinations.keys.map(&:to_s).join(", ")}",
          #  thread_ts: timestamp, # start a thread
          #)

          #results = destinations_for_channel(channel).reject{ |_, phone| phone.empty? }.map do |person, phone|
          results = destinations_for_channel(channel).map do |person, phone|
            make_phone_call_cli(to: phone, message: msg) if person == 'bporter'
            OpenStruct.new({ person: person, status: send_sms(to: phone, message: msg) })
          end

          slack_connection.send_message(
            channel: channel,
            message: "*Sent SMS message* _'#{msg}'_:\n\n*Twilio status*:\n[#{twilio_results_to_str(results)}]\n\nPlease continue discussion of the incident in this thread.  For new incidents or to trigger another SMS, use the main channel.",
            thread_ts: timestamp, # start a thread
          )
        end
      end
    end
  end
end
