
require 'slackbot_frd'
require 'net/http'
require 'uri'

class BitcoinBot < SlackbotFrd::Bot
  def endpoint
    'https://min-api.cryptocompare.com/data/pricemulti?fsyms=BTC,BCH,ETH,LTC,XMR,NXS,XZC,ZEC,XRP,ADA&tsyms=USD'
  end

=begin
  {
    "BTC": {
      "USD": 3919.4
    },
    "BCH": {
      "USD": 1419.4
    },
    "ETH": {
      "USD": 283.32
    },
    "LTC": {
      "USD": 52.96
    },
    "XMR": {
      "USD": 96.98
    },
    "NXS": {
      "USD": 1.54
    },
    "XZC": {
      "USD": 10.44
    },
    "ZEC": {
      "USD": 232.77
    },
    "XRP": {
      "USD": 0.231
    },
    "ADA": {
      "USD": 0.45
    }
  }
=end

  def btc(json)
    json["BTC"]["USD"]
  end

  def bch(json)
    json["BCH"]["USD"]
  end

  def ltc(json)
    json["LTC"]["USD"]
  end

  def eth(json)
    json["ETH"]["USD"]
  end

  def xmr(json)
    json["XMR"]["USD"]
  end

  def nxs(json)
    json["NXS"]["USD"]
  end

  def xzc(json)
    json["XZC"]["USD"]
  end

  def zec(json)
    json["ZEC"]["USD"]
  end

  def xrp(json)
    json["XRP"]["USD"]
  end

  def ada(json)
    json["ADA"]["USD"]
  end

  def coins(message)
    retval = []
    retval.push('BTC') if has_btc?(message)
    retval.push('BCH') if has_bch?(message)
    retval.push('LTC') if has_ltc?(message)
    retval.push('ETH') if has_eth?(message)
    retval.push('XMR') if has_xmr?(message)
    retval.push('NXS') if has_nxs?(message)
    retval.push('XZC') if has_xzc?(message)
    retval.push('ZEC') if has_zec?(message)
    retval.push('XRP') if has_xrp?(message)
    retval.push('ADA') if has_ada?(message)
    retval
  end

  def has_multiple_coins?(message)
    coins(message).count > 1
  end

  def has_crypto_coin?(message)
    message =~ /:cryptocoin:/i
  end

  def has_btc?(message)
    has_crypto_coin?(message) || message =~ /:bi?tc(oin)?:/i
  end

  def has_bch?(message)
    has_crypto_coin?(message) || message =~ /:bch:|:bitcoin-cash:/i
  end

  def has_ltc?(message)
    has_crypto_coin?(message) || message =~ /:li?te?c(oin)?:/i
  end

  def has_eth?(message)
    has_crypto_coin?(message) || message =~ /:eth(er)?(eum)?:/i
  end

  def has_xmr?(message)
    has_crypto_coin?(message) || message =~ /:xmr:|:monero:/i
  end

  def has_nxs?(message)
    #has_crypto_coin?(message) || message =~ /:nxs|nexus:/i
    has_crypto_coin?(message) || message =~ /:nxs:/i
  end

  def has_xzc?(message)
    has_crypto_coin?(message) || message =~ /:xzc:|:zcoin:/i
  end

  def has_zec?(message)
    has_crypto_coin?(message) || message =~ /:zec:|:zcash:/i
  end

  def has_xrp?(message)
    has_crypto_coin?(message) || message =~ /:xrp:|:ripple:/i
  end

  def has_ada?(message)
    has_crypto_coin?(message) || message =~ /:ada:/i
  end

  def has_any_coins?(message)
    [
      has_btc?(message),
      has_bch?(message),
      has_ltc?(message),
      has_eth?(message),
      has_xmr?(message),
      has_nxs?(message),
      has_xzc?(message),
      has_zec?(message),
      has_xrp?(message),
      has_ada?(message)
    ].any?
  end

  def right_pad_zeros(price)
    '%.2f' % price
  end

  def val_str(coin, json)
    ":#{coin.downcase}:  *1* #{coin} == $*#{right_pad_zeros(json[coin]['USD'])}* _USD_"
  end

  def cur_values(slack_connection, channel, thread_ts)
    SlackbotFrd::Log.debug('Requesting cryptocoin values')
    JSON.parse(Net::HTTP.get_response(URI.parse(endpoint)).body)
  rescue Exception => e
    slack_connection.send_message(
      channel: channel,
      message: "Error returned by Cyptocompare API: #{e.message}",
      thread_ts: thread_ts,
      username: 'Cryptocoin Error',
      avatar_emoji: ':x:'
    )
    nil
  end

  def val_strs(message, slack_connection, channel, thread_ts)
    json = cur_values(slack_connection, channel, thread_ts)
    SlackbotFrd::Log.debug("JSON returned from cryptocoin API: #{json}")
    json ? coins(message).map{|coin| val_str(coin, json) }.join("\n") : nil
  end

  def username(message)
    return 'Crypto Coin bot' if has_multiple_coins?(message)
    return 'Bitcoin Bot' if has_btc?(message)
    return 'Bitcoin Cash Bot' if has_bch?(message)
    return 'Ethereum Bot' if has_eth?(message)
    return 'Litecoin Bot' if has_ltc?(message)
    return 'Monero Bot' if has_xmr?(message)
    return 'Zcoin Bot' if has_xzc?(message)
    return 'Nexus Bot' if has_nxs?(message)
    return 'Zcash Bot' if has_zec?(message)
    return 'Ripple Bot' if has_xrp?(message)
    return 'Ada Bot' if has_ada?(message)
    'Bitcoin Bot'
  end

  def avatar_emoji(message)
    return ':cryptocoin:' if has_multiple_coins?(message)
    return ':btc:' if has_btc?(message)
    return ':bch:' if has_bch?(message)
    return ':eth:' if has_eth?(message)
    return ':ltc:' if has_ltc?(message)
    return ':xmr:' if has_xmr?(message)
    return ':xzc:' if has_xzc?(message)
    return ':nxs:' if has_nxs?(message)
    return ':zec:' if has_zec?(message)
    return ':xrp:' if has_xrp?(message)
    return ':ada:' if has_ada?(message)
    ':btc:'
  end

  def add_callbacks(slack_connection)
    slack_connection.on_message do |user:, channel:, message:, timestamp:, thread_ts:|
      if message && user != :bot && user != 'nexy' && timestamp != thread_ts && has_any_coins?(message)
        SlackbotFrd::Log.info("Fetching crypto currency values for coins '[#{coins(message).join(', ')}]' for user '#{user}' in channel '#{channel}'")
        reply = val_strs(message, slack_connection, channel, thread_ts)
        slack_connection.send_message(
          channel: channel,
          message: reply,
          thread_ts: thread_ts,
          username: username(message),
          avatar_emoji: avatar_emoji(message)
        ) if reply
      end
    end
  end
end
