# frozen_string_literal: true

require_relative "lib/llm_mock_anthropic/version"

Gem::Specification.new do |spec|
  spec.name = "llm_mock_anthropic"
  spec.version = LlmMock::Anthropic::VERSION
  spec.authors = [ "Nate Brustein" ]
  spec.email = [ "nate@bidwrangler.com" ]

  spec.summary = "Build and (de)serialize Anthropic SDK response objects in tests."
  spec.description = <<~DESC
    Fabricate Anthropic Ruby SDK response objects — messages, content blocks,
    tool_use blocks, and streams — for tests that stub the client directly and
    return canned responses, without hitting the network or wrestling the real
    SDK's typed models. Also serializes those objects to/from plain hashes, which
    is how the deja gem records and replays them. Part of the llm_mock family.
  DESC
  spec.homepage = "https://github.com/nbrustein/llm_mock_anthropic"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[ "lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "llm_mock", ">= 0.1"

  # The `anthropic` SDK is only needed for `default_real_client` (live calls);
  # building/serializing response doubles works without it. Consumers that record
  # live calls bring their own `anthropic`.
  spec.add_development_dependency "rspec", "~> 3.0"
end
