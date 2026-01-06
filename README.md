# Nonacat

A Github API client - unofficial, unaffiliated

Nonacat uses [Scorpio](https://github.com/notEthan/scorpio) with [Github's OpenAPI description](https://github.com/github/rest-api-description) to be a client to the service. Nonacat builds a small amount of infrastructure to simplify things like authentication and pagination, but otherwise relies wholly on the OpenAPI document for implementation of the client.

## Usage

Nonacat is built on [Scorpio](https://github.com/notEthan/scorpio), which adds functionality to an OpenAPI document, letting the document be used as a client to the service it describes. Scorpio is in turn built on [JSI](https://github.com/notEthan/jsi). Some familiarity with both is useful in using Nonacat. Nonacat's own codebase is very small - Github's [octokit.rb](https://github.com/octokit/octokit.rb) is currently about 22,000 lines of code; Nonacat is about 100.

### Caveats

Github's OpenAPI description is quite large - 11 MB as of this writing, and the whole thing is loaded and instantiated as the client. This can be unwieldy if you do things that iterate the whole document. For example, on my machine inspecting the document (`Nonacat::GITHUB_API.inspect`) takes a full 3 minutes (though only the first time; subsequent calls are much faster as computations are cached). This is a problem if, for example, you call a method that does not exist on a node in the document; when a `NoMethodError` is raised, the receiver is inspected, resulting in an error message that is very large and slow to generate.

### Authentication

Github authentication credentials, which are documented at <https://docs.github.com/en/rest/authentication>, are passed to [Faraday::Request::Authorization](https://rubydoc.info/gems/faraday/Faraday/Request/Authorization) from {Nonacat.authorization}.

Authentication typically looks like:

```ruby
Nonacat.authorization = ['Bearer', 'github_pat_2kxqIkfByCRkCGT2...']
# or
Nonacat.authorization = [:basic, 'notEthan', 'p4$$w0rd']
```

### Operations

Requests to the API are made using an OpenAPI Operation (a [`Scorpio::OpenAPI::Operation`](https://rubydoc.info/gems/scorpio/Scorpio/OpenAPI/Operation)), a part of the OpenAPI description that describes the form of the request and response. An operation can be identified by a templated path and HTTP method, or by id (the `operationId` property of the operation).

For example, the operation to [get a repository](https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#get-a-repository) is a HTTP get request to `/repos/{owner}/{repo}`, accessed in the OpenAPI document like so:

```ruby
get_repo_operation = Nonacat::GITHUB_API.paths['/repos/{owner}/{repo}'].get
```

Its id is `repos/get` (from `get_repo_operation.operationId`). You can use such an id to retrieve an operation, e.g. `Nonacat::GITHUB_API.operations['repos/get']`. Finding the id of an operation can be slightly inconvenient as it is not included on Github's HTML pages of API documentation. Available `operationId`s can be iterated with e.g. `Nonacat::GITHUB_API.operations.map(&:operationId)` or `Nonacat::GITHUB_API.operations.tagged("gists").map(&:operationId)`.

### `nonacat` executable

Nonacat includes an executable `nonacat`, which is just IRB with nonacat loaded and some additions for convenience:

- Authentication is loaded from the same source as the github [`gh` CLI](https://cli.github.com/), if available.
- Tab-completable references to operations are defined. Github's operations are categorized, e.g. the `repos/get` operation with category `repos`. The `nonacat` executable defines constants like `Nonacat::REPOS` for each category, which in turn contain constants for each operation. With these, `Nonacat::REPOS::GET` refers to the same operation as `Nonacat::GITHUB_API.operations['repos/get']`.

### Links

Many Github resources link to other resources with inline URLs, e.g. a repo resource has a `forks_url` property linking to the `repos/list-forks` operation's path. Nonacat extends these URLs with {Nonacat::Link} and the linked resource can be retrieved with `#get`, e.g. `forks = my_repo.forks_url.get`. (See the example "Get linked repository forks" below.)

### Pagination

Many Github API operations paginate results. {Nonacat.paginate_items} abstracts pagination - see its method doc, and examples below.

### Examples

- Get Zen (no auth required)

```ruby
Nonacat::GITHUB_API.operations["meta/get-zen"].run
# => "Non-blocking is better than blocking."
```

- Get repository

```
repo = Nonacat::GITHUB_API.operations["repos/get"].run(owner: 'notEthan', repo: 'scorpio')
```

Returns (trimmed)

```
#{<JSI (Nonacat::Github::FullRepository)>
  "id" => 69611598,
  "name" => "scorpio",
  "full_name" => "notEthan/scorpio",
  "owner" => #{<JSI (Nonacat::Github::SimpleUser)>
    "login" => "notEthan",
  },
  "url" => #<JSI (Nonacat::Github::FullRepository.properties["url"]) "https://api.github.com/repos/notEthan/scorpio">,
  "forks_url" => #<JSI (Nonacat::Github::FullRepository.properties["forks_url"]) "https://api.github.com/repos/notEthan/scorpio/forks">,
  "language" => "Ruby",
}
```

- Get linked repository forks (using `repo` from previous example)

```
forks = repo.forks_url.get
```

That connects the `forks_url` to the `repos/list-forks` operation, essentially running `forks = Nonacat.operations["repos/list-forks"].run(owner: 'notEthan', repo: 'scorpio')`

Returns (trimmed)

```
#[<JSI (Nonacat::Github.paths["/repos/{owner}/{repo}/forks"].get.responses["200"].content["application/json"].schema)>
  #{<JSI (Nonacat::Github::MinimalRepository)>
    "id" => 86715358,
    "name" => "scorpio",
    "full_name" => "mathieujobin/scorpio",
    "owner" => #{<JSI (Nonacat::Github::SimpleUser)>
      "login" => "mathieujobin",
    },
    "fork" => true,
    "url" => #<JSI (Nonacat::Github::MinimalRepository.properties["url"]) "https://api.github.com/repos/mathieujobin/scorpio">,
    "forks_url" => #<JSI (Nonacat::Github::MinimalRepository.properties["forks_url"]) "https://api.github.com/repos/mathieujobin/scorpio/forks">,
    "language" => "Ruby",
  }
]
```

- Search code, paginated (requires auth) - this pauses between each item; press enter to continue or `q` + enter to quit.

```ruby
Nonacat.paginate_items('search/code', q: 'nonacat', per_page: 4) do |item|
  pp(item)
  break if gets.chomp == 'q'
end
```

Output (trimmed):

```
#{<JSI (Nonacat::Github::CodeSearchResultItem)>
  "name" => "nonacat.rb",
  "path" => "lib/nonacat.rb",
  "url" => #<JSI (Nonacat::Github::CodeSearchResultItem.properties["url"])
    "https://api.github.com/repositories/898892904/contents/lib/nonacat.rb?ref=a253ff2a2c9b1229f2feea63f22a6ba7b21d1dd3"
  >,
  "repository" => #{<JSI (Nonacat::Github::MinimalRepository)>
    "name" => "nonacat",
    "full_name" => "notEthan/nonacat",
    "owner" => #{<JSI (Nonacat::Github::SimpleUser)>
      "login" => "notEthan",
    },
    "html_url" => #<JSI (Nonacat::Github::MinimalRepository.properties["html_url"])
      "https://github.com/notEthan/nonacat"
    >,
  },
  "score" => 1.0
}
```

- Create a gist

```ruby
gist = Nonacat::GITHUB_API.operations['gists/create'].run(
  body_object: {
    description: "test #{rand(1000)}",
    files: {
      'foo.rb' => {content: 'require "nonacat"'}
    },
    public: true,
  }
)
```

Returns (trimmed)

```
#{<JSI (Nonacat::Github::GistSimple)>
  "url" => "https://api.github.com/gists/729cbe8c58e7698702af6a5c51d45725",
  "html_url" => "https://gist.github.com/notEthan/729cbe8c58e7698702af6a5c51d45725",
  "files" => #{<JSI (Nonacat::Github::GistSimple.properties["files"])>
    "foo.rb" => #{<JSI (Nonacat::Github::GistSimple.properties["files"].additionalProperties)>
      "filename" => "foo.rb",
      "language" => "Ruby",
      "content" => "require \"nonacat\"",
    }
  },
  "description" => "test 3",
  "owner" => #{<JSI (Nonacat::Github::SimpleUser)>
    "login" => "notEthan",
  },
}
```

- Get the date when each tag in a repo was committed - this uses pagination, and nests API calls; getting rate limited is possible on a repository with many tags.

```ruby
Nonacat.paginate_items("repos/list-tags", owner: 'notEthan', repo: 'nonacat').map do |tag|
  {
    name: tag.name,
    # tag.commit includes very little; its `url` links to get the full commit resource
    date: tag.commit.url.get.commit.committer.date,
  }
end
```

## Development

- git clone
- `bin/nonacat_update` to fetch the latest Github OpenAPI document, if needed

## License

The gem is available under the terms of the [MIT License](https://opensource.org/licenses/MIT).
