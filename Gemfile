source "https://rubygems.org"

gemspec

# Use the sibling checkout when developing the family together; otherwise resolve
# the published gem (e.g. on CI, where only this repo is checked out).
sibling = File.expand_path("../llm_mock", __dir__)
gem "llm_mock", path: sibling if Dir.exist?(sibling)
