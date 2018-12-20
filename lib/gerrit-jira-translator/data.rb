require_relative 'gerr_jira_channel_prefs'
require_relative '../dynamo'

class GerritJiraData
  FULL = 'full_ticket'.freeze
  LINK = 'link_only'.freeze
  OFF  = 'off'.freeze

  attr_reader :channel, :channel_settings

  def initialize(channel:)
    @db = DynamoDB.new(botname: 'nexy')
    @channel = channel

    # We used to create the table here if it doesn't exist, but I removed the
    # IAM permissions to harden nexy down since table creation is rare and
    # only needs to be done one time.
    # @db.create_table(channel_settings_table_name, if_not_exist: true)

    retrieve_channel_settings(channel)
  end

  def valid_keys
    %w[
      jira_expansion
    ]
  end

  def valid_vals(key)
    if key == 'jira_expansion'
      return [
        FULL,
        LINK,
        OFF
      ]
    end
    []
  end

  def show?
    channel_on?
  end

  def channel_on?
    channel_abbrev? || channel_full?
  end

  def channel_off?
    @channel_settings.jira_expansion == OFF
  end

  def channel_abbrev?
    @channel_settings.jira_expansion == LINK
  end

  def channel_full?
    @channel_settings.jira_expansion == FULL
  end

  def set_channel_prefs(gerr_jira_channel_prefs)
    # Uncomment the below when restoring config functionality
    @db.put_item(
      table: channel_settings_table_name,
      primary: @channel,
      attrs: { prefs: gerr_jira_channel_prefs.to_json }
    )
  end

  def channel_settings_table_name
    'gerrit_jira_translator_channel_settings'
  end

  def retrieve_channel_settings(channel = @channel)
    # The channel settings are in the channel_settings table with
    # channel being the primary key

    # Uncomment the below when restoring config functionality
    #i = @db.get_item(
    #  table: channel_settings_table_name,
    #  primary: channel
    #).item
    #@channel_settings = GerritJiraChannelPrefs.from_json(
    #  i ? i['prefs'] : nil
    #)
    @channel_settings = GerritJiraChannelPrefs.from_json(nil) # Remove me
    @channel_settings
  end
end
