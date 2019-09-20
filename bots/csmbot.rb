require 'slackbot_frd'
require 'net/http'
require 'uri'

class CsmBot < SlackbotFrd::Bot
  MAX_HITS = 15
  DATA_FILE = 'data/csm_lookup.json'

  # csmlookup "account name"
  def endpoint
    'https://icanhazdadjoke.com/'
  end

  def matches_channel?(channel)
    #%w[bps_test_graveyard].include?(channel)
    true
  end

  def contains_trigger(message)
    message =~ /\s*^csmlookup/i
  end

  def extract_search_term(message)
    message.gsub(/\s*^csmlookup/i, '').strip
  end

  def render_csms(search_term)
    csms = if search_term.empty?
             lookup_csms('.*')
           else
             lookup_csms(search_term)
           end
    if csms.empty?
      "No CSMs or companies matched the term '#{search_term}'"
    else
      csms \
        .map { |csm| "#{csm['company']}: #{csm['csm']}" } \
        .join("\n")
    end
  end

  def all_csms
    JSON.parse(File.read(DATA_FILE))
  end

  def lookup_csms(search_term)
    hits = all_csms.select do |csm|
      #[csm['company'], csm['csm']].any? { |t| t =~ /#{search_term}/i } 
      csm.values.any? { |t| t =~ /#{search_term}/i } 
    end
  end

  def get_channel(sc, user, channel, message)
    if message.split("\n") > MAX_HITS
      get_pm_channel(user)
    else
      channel
    end
  end

  def handle_small_msg(sc, user, channel, message, thread_ts, search_term)
    sc.send_message(
      channel: channel,
      message: message,
      thread_ts: thread_ts,
    )
    sc.send_message(
      channel: 'nexy-log',
      message: "Sent #{message.split("\n").count} CSM lookup for user '#{user}' search term '#{search_term}' directly to channel '#{channel}'"
    )
  end

  def handle_large_msg(sc, user, channel, message, thread_ts, search_term)
    sc.send_message(
      channel: channel,
      message: "Hello #{user}!  Your CSM Lookup search had #{message.split("\n").count} results, which is a bit large for a common channel.  I have sent you the results via DM",
      thread_ts: thread_ts
    )
    sc.send_im(
      user: user,
      message: "Hello #{user}!  Your CSM Lookup search for '#{search_term}' in ##{channel} returned a lot of results.  Here they are:\n\n#{message}",
    )
    sc.send_message(
      channel: 'nexy-log',
      message: "Sent a DM to user '#{user}' with #{message.split("\n").count} CSM lookup results for search term '#{search_term}'"
    )
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy' && matches_channel?(channel) && timestamp != thread_ts && contains_trigger(message)
        search_term = extract_search_term(message)
        SlackbotFrd::Log.info("Looking up CSM or company '#{search_term}' for user '#{user}' in channel '#{channel}'")
        message = render_csms(search_term)
        
        if message.split("\n").count > MAX_HITS
          handle_large_msg(slack_connection, user, channel, message, thread_ts, search_term)
        else
          handle_small_msg(slack_connection, user, channel, message, thread_ts, search_term)
        end
      end
    end
  end
end
