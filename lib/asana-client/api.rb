module Asana
  class API
    attr_accessor :api_token
    API_URL = "https://app.asana.com/api/1.0/"

    def initialize(token)
      @api_token = token
    end

    # perform a GET request and return the response body as an object
    def get(url)
      http_request(Net::HTTP::Get, url, nil, nil)
    end

    # perform a PUT request and return the response body as an object
    def put(url, data, query = nil)
      http_request(Net::HTTP::Put, url, data, query)
    end

    # perform a POST request and return the response body as an object
    def post(url, data, query = nil)
      http_request(Net::HTTP::Post, url, data, query)
    end

    # perform an HTTP request to the Asana API
    def http_request(type, url, data, query)
      # set up http object
      uri = URI.parse API_URL + url
      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # all requests are json
      header = { "Content-Type" => "application/json" }

      # make request
      req = type.new("#{uri.path}?#{uri.query}", header)
        req.basic_auth api_token, ''

      if req.respond_to?(:set_form_data) && !data.nil?
        req.set_form_data data
      end

      res = http.start { |http| http.request req  }

      # return request object
      JSON.parse(res.body)
    end
  end
end
