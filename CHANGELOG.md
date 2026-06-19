# Changelog

All notable changes to this project are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-19

### Added
- Initial release, extracted from the `deja` gem.
- `LlmMock::Anthropic` response structs (`Message`, `Stream`, `TextBlock`,
  `ToolUseBlock`) and `.text` / `.tool_use` / `.message` / `.stream` builders.
- `LlmMock::Anthropic::Provider` implementing the `llm_mock` contract
  (build_client, call_real, serialize, deserialize, prompt_for).
