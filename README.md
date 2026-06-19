# llm_mock_anthropic

When you test Ruby code that calls the Anthropic API, you usually don't want it
hitting the network. One clean way to avoid that is to **stub your Anthropic
client and return a canned response object** — but that runs into a wall:
constructing a realistic Anthropic SDK response by hand is genuinely painful.
A real `Anthropic::Message` needs `id`, `model`, `role`, `type`, `usage`,
`stop_reason`, and typed content blocks; tool calls are nested; and **streaming
responses have no simple object to fake at all**.

`llm_mock_anthropic` gives you small, ergonomic stand-ins for exactly those
response shapes — messages, text blocks, tool_use blocks, and streams — so your
stub can return something your code happily consumes:

```ruby
allow(client.messages).to receive(:create).and_return(
  LlmMock::Anthropic.message([
    LlmMock::Anthropic.tool_use(id: "tu_1", name: "save_summary", input: {"text" => "…"}),
  ])
)
```

## Why object-level (and when not to)

The common community approach is to stub at the **HTTP layer** (VCR/WebMock):
record real HTTP and let the SDK deserialize it. That's a great fit when you can
make a real call once. Stub at the **object layer** — what this gem is for — when
that's awkward, most often because:

- **Streaming.** Replaying SSE streams through VCR is fiddly; returning a
  `Stream` double is trivial.
- **You want to script the model's behavior** deterministically (e.g. "this turn
  calls the `complete` tool") without recording anything.

If you want to *record real calls once and replay them* rather than hand-script
responses, see [`deja`](https://github.com/nbrustein/deja) — it builds on this
gem.

## Installation

```ruby
# Gemfile
group :test do
  gem "llm_mock_anthropic"
end
```

## What you get

Response value objects (duck-typed to the SDK's response surface — `.content`,
block fields, `.text`, `.accumulated_message`):

| Builder | Returns | Shape |
| --- | --- | --- |
| `LlmMock::Anthropic.text(str)` | `TextBlock` | `.type`, `.text` |
| `LlmMock::Anthropic.tool_use(id:, name:, input:)` | `ToolUseBlock` | `.type`, `.id`, `.name`, `.input` |
| `LlmMock::Anthropic.message(blocks)` | `Message` | `.content` |
| `LlmMock::Anthropic.stream(text_chunks:, message:)` | `Stream` | `.text`, `.accumulated_message` |

The structs are also available directly (`LlmMock::Anthropic::Message.new(...)`)
if you prefer.

### Example: a streamed tutor turn that ends by calling a tool

```ruby
fake = LlmMock::Anthropic.stream(
  text_chunks: [ "Here's the core idea. " ],
  message: LlmMock::Anthropic.message([
    LlmMock::Anthropic.text("Here's the core idea. "),
    LlmMock::Anthropic.tool_use(id: "tu_done", name: "complete", input: {}),
  ]),
)
allow(client.messages).to receive(:stream).and_return(fake)
```

Your code reads `fake.text` (the chunks) and `fake.accumulated_message.content`
(the final blocks) exactly as it would a real stream.

## For tool authors

`LlmMock::Anthropic::Provider` implements the
[`llm_mock`](https://github.com/nbrustein/llm_mock) contract — it builds a stub
client routed through a responder, invokes the real client, and
serializes/deserializes responses to/from plain hashes. That's how `deja` uses
this gem to record and replay Anthropic calls. You don't need any of that to use
the builders above.

## License

MIT — see [LICENSE](LICENSE).
