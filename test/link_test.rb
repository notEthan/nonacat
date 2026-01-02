require_relative('test_helper')

describe("Nonacat::Link") do
  describe("response link url") do
    it("#get") do
      org = Nonacat::GITHUB_API.operations["orgs/get"].run(org: 'github')
      assert(org.repos_url.is_a?(Nonacat::Link))
      repos = org.repos_url.get
      assert(repos.first.jsi_schemas.include?(Nonacat::GITHUB_API.components.schemas['minimal-repository']))
      assert_equal('github', repos.first.owner.login)
    end
  end
end
