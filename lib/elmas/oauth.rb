require "mechanize"
require "uri"
require File.expand_path("../utils", __FILE__)
require File.expand_path("../response", __FILE__)
require "faraday/detailed_logger"

# from https://developers.exactonline.com/#Example retrieve access token.html
module Elmas
  module OAuth
    def authorize(user_name, password, options = {})
      agent = Mechanize.new

      login(agent, user_name, password, options)
      allow_access(agent)

      code = URI.unescape(agent.page.uri.query.split("=").last)
      OauthResponse.new(get_access_token(code))
    end

    def authorized?
      response = get("/Current/Me", no_division: true)
      !response.unauthorized?
      # Do a test call, return false if 401 or any error code
    end

    # Return URL for OAuth authorization
    def authorize_url(options = {})
      options[:response_type] ||= "code"
      options[:redirect_uri] ||= redirect_uri
      params = authorization_params.merge(options)
      uri = URI("https://start.exactonline.nl/api/oauth2/auth/")
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    # Return an access token from authorization
    def get_access_token(code, _options = {})
      conn = Faraday.new(url: "https://start.exactonline.nl") do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
      params = access_token_params(code)
      conn.post do |req|
        req.url "/api/oauth2/token"
        req.body = params
        req.headers["Accept"] = "application/json"
      end
    end

    private

    def login(agent, user_name, password, options)
      # Login
      agent.get(authorize_url(options)) do |page|
        form = page.forms.first
        form["UserNameField"] = user_name
        form["PasswordField"] = password
        form.click_button
      end
    end

    def allow_access(agent)
      return if agent.page.uri.to_s.include?("getpostman")
      form = agent.page.form_with(id: "PublicOAuth2Form")
      button = form.button_with(id: "AllowButton")
      agent.submit(form, button)
    end

    def authorization_params
      {
        client_id: client_id
      }
    end

    def access_token_params(code)
      {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri
      }
    end
  end
end

module Elmas
  class OauthResponse < Response
    def body
      JSON.parse(@response.body)
    end

    def access_token
      body["access_token"]
    end

    def refresh_token
      body["refresh_token"]
    end
  end
end
