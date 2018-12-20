class GerritJiraChannelPrefs
  attr_accessor :jira_verbosity

  def initialize(jira_verbosity: default_jira_verbosity)
    valid_jira_verbosity(jira_verbosity)
    @jira_verbosity = jira_verbosity
  end

  def from_hash(hash)
    n = GerritJiraChannelPrefs.new
    n.jira_verbosity = hash[:jira_verbosity] || hash['jira_verbosity']
    n
  end

  def from_json(json)
    from_hash(json)
  end

  def to_json
    to_hash.to_json
  end

  def to_hash
    retval = []
    retval[:jira_verbosity] = jira_verbosity
    retval
  end

  def default_jira_verbosity
    'full_ticket'
  end

  def jira_verbosity_settings
    %w[
      full_ticket
      link_only
      off
    ]
  end

  def valid_jira_verbosity?(verbosity)
    jira_verbosity_settings.include?(verbosity)
  end

  private

  def validate_jira_verbosity(verbosity)
    unless valid_jira_verbosity?(verbosity)
      raise ArgumentError, "Verbosity must be one of '#{jira_verbosity_settings.join(', ')}'"
    end
  end
end
