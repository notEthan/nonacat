# frozen_string_literal: true

require("nonacat/version")
require("scorpio")
require("pathname")
require("zlib")

module Nonacat
  GITHUB_API_PATH = Pathname.new(__dir__).join('../github-rest-api-description/api.github.com.oas-3-0.json.zz')

  # A [Scorpio::OpenAPI::Document](https://rubydoc.info/gems/scorpio/Scorpio/OpenAPI/Document) for Github's API
  GITHUB_API = Scorpio.new_document(JSON.parse(Zlib.inflate(GITHUB_API_PATH.read)))

  GITHUB_API.faraday_builder = proc do |conn|
    conn.request(:authorization, *Nonacat.authorization) if Nonacat.authorization
  end

  class << self
    # Authorization params passed to [Faraday::Request::Authorization](https://rubydoc.info/gems/faraday/Faraday/Request/Authorization).
    #
    #     Nonacat.authorization = ['Bearer', 'github_pat_2kxqIkfByCRkCGT2...']
    #     Nonacat.authorization = [:basic, 'notEthan', 'p4$$w0rd']
    attr_accessor(:authorization)
  end
end
