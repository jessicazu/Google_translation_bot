class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'net/http'
  require 'uri'
  require 'json'
  require 'htmlentities'

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
    detect_url = URI.parse('https://translation.googleapis.com/language/translate/v2/detect')
    params = {
      q: text,
      key: "AIzaSyC4cdgNESXrk7hlXxWlqUgtqykFh290J4g"
    }
    detected_res = Net::HTTP.post_form(detect_url, params)
    detected_lang = JSON.parse(detected_res.body)["data"]["detections"].first.first["language"]

    case detected_lang
    when "ja"
      target_lang = "en"
    else
      target_lang = "ja"
    end

    translate_url = URI.parse('https://www.googleapis.com/language/translate/v2')
    params = {
      q: text,
      target: target_lang,
      source: detected_lang,
      key: "AIzaSyC4cdgNESXrk7hlXxWlqUgtqykFh290J4g"
    }
    # url.query = URI.encode_www_form(params)
    translated_res = Net::HTTP.post_form(translate_url, params)
    translated_text = JSON.parse(translated_res.body)["data"]["translations"].first["translatedText"]
    HTMLEntities.new.decode(translated_text)
  end
end
