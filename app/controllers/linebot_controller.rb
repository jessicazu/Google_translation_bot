class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'net/http'
  require 'uri'
  require 'json'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          text = event.message['text']
          translated_text = translate(text)
          message = {
            type: 'text',
            text: translated_text
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end

  def translate(text)
    url = URI.parse('https://www.googleapis.com/language/translate/v2')
    params = {
      q: text,
      target: "en",
      source: "ja",
      key: ['GOOGLE_TRANSLATE_API_KEY']
    }
    url.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(url)
    JSON.parse(res.body)["data"]["translations"].first["translatedText"]
  end
end
