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
      # Name schema components like Github::CodeSearchResultItem, Github::Repository, etc.
      if node.jsi_is_schema? && !node.jsi_schema_module_name
        if node.jsi_ptr.parent == JSI::Ptr['components', 'schemas']
          const_name = JSI::Util::Private.const_name_from_parts(node.jsi_ptr.tokens.last.to_s.split(/[_-]/)) # TODO shouldn't use JSI privates
          Github.const_set(const_name, node.jsi_schema_module) if const_name && !Github.constants.include?(const_name.to_sym)
        end
      end
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

    # Yields each item in each page of results from the indicated operation.
    #
    # @param operation [String, Scorpio::OpenAPI::Operation] an operationId or an Operation
    # @yield [JSI::Base] each item in each page of results
    # @return [nil, Enumerator]
    def paginate_items(operation, **conf, &block)
      return to_enum(__method__, operation, **conf) unless block_given?
      operation = operation.is_a?(Scorpio::OpenAPI::Operation) ? operation : GITHUB_API.operations[operation]

      # detect pagination by response schemas
      each_item = nil
      operation.responses.each do |status, oa_response|
        next if status.to_s !~ /^2..$/
        oa_response['content'].each_value.select(&:schema).each do |oa_media_type|
          # TODO not very good
          oa_media_type.schema.each_inplace_applicator_schema(nil) do |ias|
            if ias.items
              # each page is an array with each item
              each_item = proc { |body_object| body_object }
            elsif ias.properties && ias.properties['items'] && ias.properties['items'].items
              # each page is an object with property 'items' containing an array with each item
              each_item = proc { |body_object| body_object.items }
            end
          end
        end
      end
      raise("pagination not detected in operation: #{operation.pretty_inspect.chomp}") if !each_item

      operation.each_link_page(**conf) do |page_ur|
        each_item[page_ur.response.body_object].each(&block)
      end
    end
  end
end
