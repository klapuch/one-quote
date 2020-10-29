# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'json'
require_relative 'config.local'

class Quote
  def value
    html = Nokogiri::HTML(page)
    text = html.xpath(
      'substring(
        //h3[@class="blockquote-text"]/a/text(),
        2,
        string-length(//h3[@class="blockquote-text"]/a/text()) - 2
      )'
    )
    origin = html.xpath('//p[@class="blockquote-origin"]/a/text()')
    about = html.xpath(
      'normalize-space(
        //p[@class="blockquote-origin"]/a/following-sibling::text()
      )'
    )
    {
      text: text.to_s,
      origin: origin.to_s,
      about: about.to_s
    }
  end

  def page
    Net::HTTP.get(URI('https://citaty.net/citaty/nahodny-citat/'))
  end
end

class Telegram
  def initialize(token)
    @token = token
  end

  def request(endpoint, parameters)
    Net::HTTP.post(
      URI(url(endpoint)),
      parameters.to_json,
      'Content-Type': 'application/json'
    )
  end

  def url(endpoint)
    format('https://api.telegram.org/bot%s/%s', @token, endpoint)
  end
end

class TelegramMessage
  def initialize(client, text, chatId)
    @client = client
    @text = text
    @chatId = chatId
  end

  def send
    @client.request(
      'sendMessage',
      {
        chat_id: @chatId,
        parse_mode: 'html',
        text: @text
      }
    )
  end
end

class Feed
  def initialize(telegram, subscribers)
    @telegram = telegram
    @subscribers = subscribers
  end

  def consume
    quote = Quote.new.value
    message = format(
      "<em>%s</em>\n\n<strong>%s</strong> - %s",
      quote[:text],
      quote[:origin],
      quote[:about]
    )
    @subscribers.each { |subscriber| TelegramMessage.new(@telegram, message, subscriber).send }
  end
end

telegram = Telegram.new(CONFIG[:telegram][:token])
Feed.new(telegram, CONFIG[:telegram][:subscribers]).consume
