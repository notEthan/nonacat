# frozen_string_literal: true

require("nonacat/version")
require("scorpio")
require("pathname")
require("zlib")
require("faraday/follow_redirects")

module Nonacat
  oass = ['3-0', '3-1']
  oas = !ENV['NC_OAS'] ? oass.first : oass.include?(ENV['NC_OAS']) ? ENV['NC_OAS'] : abort("expected env NC_OAS in #{oass.join(', ')}")
  GITHUB_API_PATH = Pathname.new(__dir__).join(-"../github-rest-api-description/api.github.com.oas-#{oas}.json.zz")

  # A [Scorpio::OpenAPI::Document](https://rubydoc.info/gems/scorpio/Scorpio/OpenAPI/Document) for Github's API
  GITHUB_API = Scorpio.new_document(
    JSON.parse(Zlib.inflate(GITHUB_API_PATH.read)),
    after_initialize: proc do |node|
    end,
  )

  Github = GITHUB_API.jsi_schema_module_connection
  module Github end

  GITHUB_API.faraday_builder = proc do |conn|
    conn.request(:authorization, *Nonacat.authorization) if Nonacat.authorization
    conn.use(Faraday::FollowRedirects::Middleware)
  end

  class << self
    # Authorization params passed to [Faraday::Request::Authorization](https://rubydoc.info/gems/faraday/Faraday/Request/Authorization).
    #
    #     Nonacat.authorization = ['Bearer', 'github_pat_2kxqIkfByCRkCGT2...']
    #     Nonacat.authorization = [:basic, 'notEthan', 'p4$$w0rd']
    attr_accessor(:authorization)
  end
end
