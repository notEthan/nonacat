require_relative('test_helper')

describe("Nonacat.paginate_items") do
  describe("array") do
    it("paginates items") do
      n = 0
      Nonacat.paginate_items("repos/list-for-org", org: 'github', per_page: 2) do |repo|
        assert_equal('github', repo.owner.login)
        n += 1
        break if n > 2
      end
      assert(n > 2)
    end
  end

  describe("object with 'items' array") do
    it("paginates items") do
      n = 0
      Nonacat.paginate_items("search/commits", q: 'nonacat', per_page: 2) do |item|
        assert(item.jsi_schemas.include?(Nonacat::GITHUB_API.components.schemas['commit-search-result-item']))
        n += 1
        break if n > 2
      end
      assert(n > 2)
    end
  end
end
