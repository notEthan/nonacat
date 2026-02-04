# Nonacat

A Github API client - unofficial, unaffiliated

Nonacat uses [Scorpio](https://github.com/notEthan/scorpio) with [Github's OpenAPI description](https://github.com/github/rest-api-description) to be a client to the service. Nonacat builds a small amount of infrastructure to simplify things like authentication, but otherwise relies wholly on the OpenAPI document for implementation of the client.

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
  "url" => "https://api.github.com/repos/notEthan/scorpio",
  "forks_url" => "https://api.github.com/repos/notEthan/scorpio/forks",
  "language" => "Ruby",
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

## Development

- git clone
- `bin/nonacat_update` to fetch the latest Github OpenAPI document, if needed

## License

The gem is available under the terms of the [MIT License](https://opensource.org/licenses/MIT).
