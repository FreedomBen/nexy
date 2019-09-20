require 'slackbot_frd'
require 'securerandom'

require_relative '../lib/jira/issue'
require_relative '../lib/gerrit/change'

require_relative '../lib/gerrit-jira-translator/data'

class GerritJiraTranslator < SlackbotFrd::Bot
  def whitelisted_prefixes
    'BOR|LOAN|SUP|PLAT|DT|PT|DK|DIS|SAND|PR|SPA|SUP|ME|NEX|BXD|INFRA'
  end

  def blacklisted_channels
    %w[
      bps_test_graveyard
      platform_team
      nexus_team
      lo-team
      borrower-experience
    ]
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      #if channel =~ /bps_test_graveyard/ && message && user != :bot && user != 'nexy' && timestamp != thread_ts
      if message && user != :bot && user != 'nexy' && !blacklisted_channels.include?(channel) && timestamp != thread_ts
        if contains_command(message)
          handle_command(slack_connection, user, channel, message, thread_ts)
        # gerrits are disabled.  see `def contains_gerrits`
        elsif contains_gerrits(message) || contains_jiras(message)
          handle_gerrits_jiras(slack_connection, user, channel, message, thread_ts)
        end
      end
    end
  end

  def handle_command(slack_connection, user, channel, message, thread_ts)
    data = GerritJiraData.new(channel: channel)
    message = if contains_read_settings_command(message)
                SlackbotFrd::Log.debug(
                  "user '#{user}' in channel '#{channel}' is reading settings"
                )
                data.channel_settings.to_json
              elsif contains_set_settings_command(message)
                SlackbotFrd::Log.debug(
                  "user '#{user}' in channel '#{channel}' is changing settings: '#{message}'"
                )
                handle_set_settings_command(data, message)
              end
    send_msg(sc: slack_connection, channel: channel, message: message, thread_ts: thread_ts)
  end

  def handle_set_settings_command(data, message)
    _, key, val = command_key_val(message)

    return "'#{key}' is not a valid attribute" unless data.valid_keys.include?(key)
    return "'#{val}' is not a valid value for '#{key}'. Try one of #{data.valid_vals(key)}" unless data.valid_vals(key).include?(val)

    begin
      new_data = data.channel_settings
      prev_data = new_data.dup
      changed = new_data.changes?(key, val)
      new_data.set(key, val)
      data.set_channel_prefs(new_data)
      new_data = data.retrieve_channel_settings
      message = "New settings for channel '##{data.channel}': #{new_data.to_json}"
      if changed && new_data.equals?(prev_data)
        message = "#{message}\nOh no!  It looks like your changes didn't take :disappointed:"
      end
      return message
    rescue => err
      "Whoa, something went wrong over here :grimacing:\n```#{err.message}```"
    end
  end

  def handle_gerrits_jiras(slack_connection, user, channel, message, thread_ts)
    data = GerritJiraData.new(channel: channel)
    if contains_gerrits(message)
      translate_gerrits(slack_connection, user, channel, message, thread_ts)
    elsif data.show? && contains_jiras(message)
      translate_jiras(slack_connection, user, channel, message, data, thread_ts)
    else
      SlackbotFrd::Log.debug(
        "Ignoring jiras in channel '#{channel}' because " \
        'it has jiras turned off'
      )
    end
  end

  def translate_gerrits(slack_connection, user, channel, message, thread_ts)
    extracted_gerrits = extract_gerrits(message)
    if extracted_gerrits.count == 1
      translate_single_gerrits(extracted_gerrits.first, slack_connection, user, channel, message, thread_ts)
    else
      translate_multiple_gerrits(extracted_gerrits, slack_connection, user, channel, message, thread_ts)
    end
  end

  def translate_single_gerrits(extracted_gerrit, sc, user, channel, _message, thread_ts)
    change_api = Gerrit::Change.new(
      username: $slackbotfrd_conf['gerrit_username'],
      password: $slackbotfrd_conf['gerrit_password']
    )
    log_info("Translated g/#{extracted_gerrit} for user '#{user}' in channel '#{channel}'")

    msg = build_single_line_gerrit_str(extracted_gerrit, change_api)
    # msg = build_full_gerrit_str(extracted_gerrit, change_api.get(extracted_gerrit))
    send_msg(sc: sc, channel: channel, message: msg, parse: 'none', thread_ts: thread_ts)
  end

  def translate_multiple_gerrits(extracted_gerrits, sc, user, channel, _message, thread_ts)
    change_api = Gerrit::Change.new(
      username: $slackbotfrd_conf['gerrit_username'],
      password: $slackbotfrd_conf['gerrit_password']
    )
    gerrits = extracted_gerrits.map do |gn|
      log_info("Translated g/#{gn} for user '#{user}' in channel '#{channel}'")
      build_single_line_gerrit_str(gn, change_api)
    end
    send_msg(sc: sc, channel: channel, message: gerrits.join("\n"), parse: 'none', thread_ts: thread_ts)
  end

  def translate_jiras(slack_connection, user, channel, message, data, thread_ts)
    message = if data.channel_full?
                translate_full_jiras(slack_connection, user, channel, message)
              elsif data.channel_abbrev?
                translate_abbrev_jiras(slack_connection, user, channel, message)
              else
                ''
              end

    send_msg(sc: slack_connection, channel: channel, message: message, parse: 'none', thread_ts: thread_ts)
  end

  def translate_full_jiras(_slack_connection, user, channel, message)
    issue_api = Jira::Issue.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    jiras = extract_jiras(message).map do |jira|
      log_info("Translated #{jira[:prefix]}-#{jira[:number]} for user '#{user}' in channel '#{channel}'")

      issue_api_get = issue_api.get(jira[:id])
      if issue_api_get[:error]
        "#{jira[:id]} - #{issue_api_get[:error]}"
      else
        build_full_jira_str(jira, issue_api_get)
      end
    end

    jiras.join("\n")
  end

  def translate_abbrev_jiras(slack_connection, user, channel, message)
    extracted_jiras = extract_jiras(message)
    if extracted_jiras.count == 1
      translate_single_abbrev_jira(extracted_jiras.first, slack_connection, user, channel)
    else
      translate_multiple_abbrev_jiras(extracted_jiras, slack_connection, user, channel)
    end
  end

  def translate_single_abbrev_jira(jira, _slack_connection, user, channel)
    issue_api = Jira::Issue.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    log_info("Translated #{jira[:prefix]}-#{jira[:number]} for user '#{user}' in channel '#{channel}'")

    build_single_line_jira_str(jira, issue_api.get(jira[:id]))
  end

  def translate_multiple_abbrev_jiras(extracted_jiras, _slack_connection, user, channel)
    issue_api = Jira::Issue.new(
      username: $slackbotfrd_conf['jira_username'],
      password: $slackbotfrd_conf['jira_password']
    )
    jiras = extracted_jiras.map do |jira|
      log_info("Translated #{jira[:prefix]}-#{jira[:number]} for user '#{user}' in channel '#{channel}'")

      # jira_link(jira)
      build_single_line_jira_str(jira, issue_api.get(jira[:id]))
    end

    # ":jira: :  #{jiras.join('  |  ')}"
    jiras.join("\n")
  end

  def log_info(message)
    SlackbotFrd::Log.info(message)
  rescue IOError => e
  end

  def extract_gerrits(str)
    str.scan(/g\/(\d+)/i).map(&:first).uniq
  end

  def extract_jiras(str)
    str.scan(/(#{whitelisted_prefixes})-(\d+)/i).map do |prefix, num|
      { id: "#{prefix.upcase}-#{num}", prefix: prefix.upcase, number: num }
    end.uniq
  end

  def contains_gerrits(str)
    # g/12345
    str.downcase =~ /(^|\s|\()g\/\d{3,9}[.!?,;)\/]*($|\s)/i
    # Gerrit is not currently in use, so disable this 
    false
  end

  def contains_jiras(str)
    str.downcase =~ /(^|\s|browse\/)\(?(#{whitelisted_prefixes})-\d{1,9}\)?>?[.!?,;)]*($|\s)/i
  end

  def gerrit_url(gerr_num)
    "https://gerrit.instructure.com/#/c/#{gerr_num}/"
  end

  def gerrit_mobile_url(gerr_num)
    "https://gerrit-mobile.inseng.net/#/c/#{gerr_num}/"
  end

  def gerrit_urls(gerr_nums)
    gerr_nums.map { |gn| gerrit_url(gn) }
  end

  def jira_url(prefix, jira_num)
    "https://simplenexus.atlassian.net/browse/#{prefix.upcase}-#{jira_num}"
  end

  def jira_urls(jira_nums)
    jira_nums.map { |cn| jira_url(cn) }
  end

  def build_single_line_gerrit_str(gerrit, change_api)
    change = change_api.get(gerrit)
    project = change['project']
    owner = change['owner']['name']
    subject = change['subject']
    verified = jenkins_vote(change)
    code_review = code_review_vote(change)
    qa = qa_vote(change)
    product = product_vote(change)
    verified = verified.empty? ? '' : "( :jenkins: #{verified} )"
    code_review = code_review.empty? ? '' : "(CR: #{code_review} )"
    qa = qa.empty? ? '' : "(QA: #{qa} )"
    product = product.empty? ? '' : "(P: #{product} )"
    votes = [verified, code_review, qa, product]
    breaker = votes.all?(&:empty?) ? '' : ' - '

    return ":gerrit: :  <#{gerrit_url(gerrit)}|g/#{gerrit}> (<#{gerrit_mobile_url(gerrit)}|gerrit-mobile>) - [#{project}] - *#{owner}* - _#{subject}_#{breaker}#{votes.join(' ')}"
  rescue StandardError => e
    SlackbotFrd::Log.warn(
      "Error encountered parsing gerrit #{gerrit}'.  " \
      "Message: #{e.message}.\n#{e}"
    )
    return ":gerrit: :  <#{gerrit_url(gerrit)}|g/#{gerrit}> - _error reading status from gerrit_"
  end

  def build_full_gerrit_str(gerrit, change)
    # You can get the verification, code review, etc.
    "#{gerrit_string_header(gerrit, change)} : <#{gerrit_mobile_url(gerrit)}|:iphone:>\n" \
    "          *Project:*  #{change['project']}\n" \
    "          *Subject:*  #{change['subject']}\n" \
    "          *Verified*:  #{jenkins_vote(change, true)}\n" \
    "          *Code Review*:  #{code_review_vote(change, true)}\n" \
    "          *QA*:  #{qa_vote(change, true)}\n" \
    "          *Product*:  #{product_vote(change, true)}"
  end

  def gerrit_string_header(gerrit, change)
    ":gerrit: :  <#{gerrit_url(gerrit)}|g/#{gerrit}> : <#{gerrit_mobile_url(gerrit)}|:iphone:> - *#{change['owner']['name']}*"
  end

  def vote(category, change, minus1: ':-1:', minus2: ':x:', plus1: ':+1:', plus2: ':plus2:', include_name: false)
    name = lambda do |vote|
      if include_name
        " - #{vote['name']}"
      else
        ''
      end
    end
    return '' unless change['labels'][category]['all']
    votes = change['labels'][category]['all'].select do |vote|
      [-2, -1, 1, 2].include?(vote['value'])
    end
    votes.each do |vote|
      return "#{minus2}#{name.call(vote)}" if vote['value'] == -2
    end
    votes.each do |vote|
      return "#{plus2}#{name.call(vote)}" if vote['value'] == 2
    end
    votes.each do |vote|
      return "#{minus1}#{name.call(vote)}#{include_name && vote['name'] == 'Jenkins' ? ':jerkins:' : ''}" if vote['value'] == -1
    end
    votes.each do |vote|
      return "#{plus1}#{name.call(vote)}#{include_name && vote['name'] == 'Jenkins' ? ':jenkins:' : ''}" if vote['value'] == 1
    end
    ''
  rescue NoMethodError => e
    # If something we need is missing from the hash,
    # catch the no method error from dereferencing a
    # nil pointer and just return empty string
    ''
  end

  def jenkins_vote(change, include_name = false)
    vote('Verified', change, minus1: ':x:', plus1: ':check:', include_name: include_name)
  end

  def code_review_vote(change, include_name = false)
    vote('Code-Review', change, include_name: include_name)
  end

  def qa_vote(change, include_name = false)
    vote('QA-Review', change, minus1: ':fail:', include_name: include_name)
  end

  def product_vote(change, include_name = false)
    vote('Product-Review', change, include_name: include_name)
  end

  def build_single_line_jira_str(jira, issue)
    return issue[:error] if issue[:error]
    #":jira: :  #{priority_str(issue)}  #{story_points_str(issue)}#{jira_link(jira)}  -  (_#{status_str(issue)}_)  -  #{summary_str(issue)}"
    ":jira: :  #{story_points_str(issue)}#{jira_link(jira)}   *#{assignee_str(issue)}*  -  (_#{status_str(issue)}_)  -  #{summary_str(issue)}"
  end

  def build_full_jira_str(jira, issue)
    comp_str = lambda do
      title = '          *Component(s)*:  '
      component_str(issue).empty? ? '' : "#{title}#{component_str(issue)}\n"
    end

    "#{jira_string_header(jira, issue)}" \
    "          *Summary:*  #{summary_str(issue)}\n" \
    "#{comp_str.call}" \
    "          *Status:*  #{status_str(issue)}\n" \
    "          *Assigned to*:  #{assigned_to_str(issue)}"
  end

  def status(issue)
    # TODO add assigned to
    issue[:fields] && issue[:fields][:status] && issue[:fields][:status][:name] && issue[:fields][:status][:name].to_s
  end

  def story_points(issue)
    issue['fields'] && issue['fields']['customfield_10023'] && issue['fields']['customfield_10023'].to_s
  end

  def assignee_str(issue)
    #issue['fields'] && issue['fields']['assignee'] && issue['fields']['assignee']['name'] && issue['fields']['assignee']['name'].to_s
    assignee = issue['fields'] \
            && issue['fields']['assignee'] \
            && issue['fields']['assignee']['displayName'] \
            && issue['fields']['assignee']['displayName'].to_s
    (assignee.nil? || assignee.empty?) ? '(_Unassigned_)' : assignee
  end

  def story_points_str(issue)
    story_points_to_emoji(story_points(issue))
  end

  def status_str(issue)
    status(issue)
  end

  def priority_str(issue)
    if issue['fields'] && issue['fields']['priority'] && issue['fields']['priority']['name']
      priority_to_emoji(issue['fields']['priority']['name']) || ''
    else
      ''
    end
  end

  def priority_to_emoji(priority)
    {
      'Highest' => ':jira_highest_priority:',
      'High'    => ':jira_high_priority:',
      'Medium'  => ':jira_medium_priority:',
      'Low'     => ':jira_low_priority:',
      'Lowest'  => ':jira_lowest_priority:'
    }[priority]
  end

  def story_points_to_emoji(points)
    {
      '1.0' => ':one:',
      '2.0' => ':two:',
      '3.0' => ':three:',
      '4.0' => ':four:',
      '5.0' => ':five:',
      '6.0' => ':six:',
      '7.0' => ':seven:',
      '8.0' => ':eight:',
      '9.0' => ':nine:',
      '10.0' => ':keycap_ten:',
      '11.0' => '11',
      '12.0' => '12',
      '13.0' => '13'
    }[points] + '   '
  rescue NoMethodError
    return "*#{points}*" + '   ' if points
    ''
  end

  def summary_str(issue)
    issue['fields'] && issue['fields']['summary']
  end

  def component_str(issue)
    if issue['fields'] && issue['fields']['components']
      issue['fields']['components'].map { |c| c['name'] }.join(', ')
    else
      ''
    end
  end

  def status_str(issue)
    retval = if issue['fields'] && issue['fields']['status']
               issue['fields']['status']['name']
             else
               ''
             end
    retval.empty? ? 'Not set' : retval
  end

  def assigned_to_str(issue)
    retval = if issue['fields'] && issue['fields']['assignee']
               issue['fields']['assignee']['displayName']
             else
               ''
             end
    retval.empty? ? 'Unassigned' : retval
  end

  def jira_string_header(jira, issue)
    ":jira: #{jira_link(jira)}  " \
    "#{priority_str(issue)}  #{story_points_str(issue)}\n" \
  end

  def jira_link(jira)
    "<#{jira_link_url(jira)}|#{jira_link_text(jira)}>"
  end

  def jira_link_url(jira)
    jira_url(jira[:prefix], jira[:number])
  end

  def jira_link_text(jira)
    "#{jira[:prefix]}-#{jira[:number]}"
  end

  private

  def command_regex
    /^\@?nexy(bot)?:?\s+set\s+(\w+)\s+(\w+)/i
  end

  def read_settings_command_regex
    /^\@?nexy(bot)?:?\s+settings/i
  end

  def contains_command(message)
    contains_read_settings_command(message) ||
      contains_set_settings_command(message)
  end

  def contains_read_settings_command(message)
    message =~ read_settings_command_regex
  end

  def contains_set_settings_command(message)
    message =~ command_regex
  end

  def command_key_val(message)
    message.match(command_regex).captures
  end

  def command_key(message)
    command_key_val(message)[0]
  end

  def command_val(message)
    command_key_val(message)[1]
  end

  def pick_bot
    num = SecureRandom.random_number(160)

    return :devil   if num == 1
    return :weeping if [2, 3].include?(num)
    :nexy
  end

  def send_msg(sc:, channel:, message:, parse: 'full', thread_ts: nil)
    return if message.empty?

    #bot = pick_bot
    #if channel == 'it'
    #  sc.send_message(
    #    channel: channel,
    #    message: message,
    #    parse: parse,
    #    username: 'Roy',
    #    avatar_emoji: ':roy:',
    #    thread_ts: thread_ts
    #  )
    #elsif channel == 'pandata'
    #  sc.send_message(
    #    channel: channel,
    #    message: message,
    #    parse: parse,
    #    username: 'Moss',
    #    avatar_emoji: ':moss:',
    #    thread_ts: thread_ts
    #  )
    #elsif %w[secteam-core security secops].include?(channel)
    #  sc.send_message(
    #    channel: channel,
    #    message: message,
    #    parse: parse,
    #    username: 'Tyrion',
    #    avatar_emoji: ':tyrion:',
    #    thread_ts: thread_ts
    #  )
    #elsif bot == :devil
    #  sc.send_message(
    #    channel: channel,
    #    message: message,
    #    parse: parse,
    #    username: 'Devil Bot',
    #    avatar_emoji: ':devil:',
    #    thread_ts: thread_ts
    #  )
    #elsif bot == :weeping
    #  sc.send_message(
    #    channel: channel,
    #    message: message,
    #    parse: parse,
    #    username: 'Weeping Angel Bot',
    #    avatar_emoji: ':weeping-angel:',
    #    thread_ts: thread_ts
    #  )
    #else
      sc.send_message(
        channel: channel,
        message: message,
        parse: parse,
        thread_ts: thread_ts
      )
      sc.send_message(
        channel: 'nexy-log',
        message: "Sent to channel '#{channel}':  #{message}"
      )
    #end
  end
end
