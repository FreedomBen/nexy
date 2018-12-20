require 'slackbot_frd'
require 'crack'
require 'curb'

class Definitions
  def initialize(word, json)
    @word = word
    if !json['entry_list']
      @skunked = true
    elsif json['entry_list']['suggestion']
      @suggestions = json['entry_list']['suggestion']
    elsif json['entry_list']['entry'].is_a?(Array)
      @definitions = json['entry_list']['entry'].map { |entry_list| Definition.new(entry_list) }
    else
      @definitions = [Definition.new(json['entry_list']['entry'])]
    end
  end

  def to_s
    if @skunked
      "Sorry, I did not find any definitions for '#{@word}' and there were no suggestions."
    elsif @suggestions
      "Sorry, I did not find any definitions for '#{@word}'.\nHere are some suggestions: #{@suggestions.join(', ')}"
    else
      str = @definitions.select(&:has_definitions).join("\n")
      return str if str && !str.empty?
      "Sorry, I did not find any definitions for '#{@word}' and there were no suggestions."
    end
  end
end

class Definition
  attr_accessor :word, :fl, :hw, :pr, :definitions

  def initialize(entry_json)
    @no_definition = entry_json.nil?
    return unless entry_json

    @word = entry_json['id']
    @fl = entry_json['fl']
    @hw = entry_json['hw']
    @pr = entry_json['pr']
    @definitions = if entry_json['def']
                     entry_json['def']['dt']
                   else
                     []
                   end

    if @definitions.is_a?(Hash)
      SlackbotFrd::Log.error("definitions are in a hash!: #{@definitions}")
    elsif @definitions.is_a?(Array)
      @definitions.map! { |d| clean_defstr(d) }
    else
      @definitions = [clean_defstr(@definitions)]
    end
  end

  def has_definitions
    return false if @no_definition
    @definitions.any? { |d| !d.empty? }
  end

  def to_s
    if @no_definition
      'No definition found'
    else
      <<-DEFINITION
Definition for: *#{@word}*
    _#{@fl} | #{@hw} | #{@pr}_
#{@definitions.reject(&:empty?).map.with_index { |d, i| "    #{i + 1} - #{d}" }.join("\n")}
      DEFINITION
    end
  end

  private

  def clean_defstr(defstr)
    # test case that returned a hash was 'define soon'
    if defstr.is_a?(String)
      defstr.gsub(/^:/, '').gsub(/\<\/?.*\>/i, '')
    else
      ''
    end
  end
end

class DictionaryBot < SlackbotFrd::Bot
  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy'
        # Dictionary
        if message.downcase =~ /^(define|definition\s+for):\s+(\w+)/i
          SlackbotFrd::Log.info("Defining #{Regexp.last_match(2)} for user '#{user}' in channel '#{channel}'")
          xml = Curl.get("http://www.dictionaryapi.com/api/v1/references/collegiate/xml/#{Regexp.last_match(2)}?key=#{$slackbotfrd_conf['dictionary_key']}")
          json = Crack::XML.parse(xml.body_str)
          slack_connection.send_message(
            channel: channel,
            message: Definitions.new(Regexp.last_match(2), json).to_s,
            thread_ts: thread_ts
          )
          begin
            SlackbotFrd::Log.info("Defined #{Regexp.last_match(2)} for user '#{user}' in channel '#{channel}'")
          rescue IOError => e
          end
        # Thesaurus
        elsif message.downcase =~ /^(synonyms?|antonyms?)(\s+for)?\s+(\w+)/i
          # slack_connection.send_message(
          #   channel: channel,
          #   message: ":doh: D'oh!  Sorry this isn't implemented yet",
          #   thread_ts: thread_ts
          # )
        end
      end
    end
  end
end
