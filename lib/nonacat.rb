# frozen_string_literal: true

require("nonacat/version")
require("scorpio")
require("pathname")
require("zlib")
require("faraday/follow_redirects")

module Nonacat
  # a module for JSI instances whose content is a URL corresponding to an operation of the OpenAPI description
  module Link
    # see [JSI::Base](https://rubydoc.info/gems/jsi/JSI/Base#jsi_as_child_default_as_jsi-instance_method)
    def jsi_as_child_default_as_jsi
      !jsi_node_content.nil?
    end

    def get(**conf, &b)
      get_request(**conf, &b).run
    end

    # @return [Scorpio::Request]
    def get_request(**conf, &b)
      uri = JSI::URI[self]
      conf[:query_params] = [uri.query_values, conf.delete(:query_params), conf.delete('query_params')].inject(nil) { |c, p| c ? p ? c.merge(p) : c : p }
      GITHUB_API.operations.each do |operation|
        next if !operation.get?
        path_params = operation.uri_template.extract(operation.base_url.join(uri.merge(query: nil))) || next
        conf[:path_params] = [conf.delete(:path_params), conf.delete('path_params')].inject(path_params) { |c, p| p ? c.merge(p) : c }
        return operation.build_request(**conf, &b)
      end
      raise("no operation matched url: #{jsi_node_content}")
    end
  end

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

      node_describes_url = node.jsi_is_schema? && (
        node.keyword_value?('format', 'uri') ||
        (node.keyword_value?('type', 'string') && (
          (node.jsi_ptr.tokens.last.respond_to?(:to_str) && node.jsi_ptr.tokens.last =~ /_url\z/) ||
          (node.example.respond_to?(:to_str) && node.example['://']))))
      if node_describes_url
        node.jsi_schema_module.include(Nonacat::Link)
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
    # @param ratelimit [Boolean] {.ratelimit} each response
    # @yield [JSI::Base] each item in each page of results
    # @return [nil, Enumerator]
    def paginate_items(operation, ratelimit: true, **conf, &block)
      return to_enum(__method__, operation, **conf) unless block_given?
      operation = operation.is_a?(Scorpio::OpenAPI::Operation) ? operation : GITHUB_API.operations[operation]
      operation.each_link_page(**conf) do |page_ur|
        if page_ur.response.body_object.respond_to?(:to_ary)
          page_ur.response.body_object.each(&block)
        elsif page_ur.response.body_object.respond_to?(:to_hash) && page_ur.response.body_object.key?('items') && page_ur.response.body_object['items'].respond_to?(:to_ary)
          page_ur.response.body_object['items'].each(&block)
        else
          raise("pagination not detected in operation response.\noperation: #{operation.pretty_inspect.chomp}\nresponse ur: #{page_ur.pretty_inspect.chomp}")
        end
        Nonacat.ratelimit(page_ur) if ratelimit
      end
    end

    # If the given ur's response indicates insufficent remaining ratelimit, sleep until limit will reset
    def ratelimit(ur)
      if ur.response.headers['x-ratelimit-remaining'] && Float(ur.response.headers['x-ratelimit-remaining']) <= 1 && ur.response.headers['x-ratelimit-reset']
        sleep(1 + (Time.at(Float(ur.response.headers['x-ratelimit-reset'])) - Time.now))
      end
      ur
    end
  end
end
