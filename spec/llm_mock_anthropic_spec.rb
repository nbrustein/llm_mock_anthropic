# frozen_string_literal: true

RSpec.describe LlmMock::Anthropic do
  describe "builders" do
    it "builds a message of text and tool_use blocks" do
      message = described_class.message([
        described_class.text("hello"),
        described_class.tool_use(id: "tu_1", name: "do_thing", input: {"x" => 1}),
      ])

      text, tool = message.content
      expect([ text.type, text.text ]).to eq([ :text, "hello" ])
      expect([ tool.type, tool.id, tool.name, tool.input ]).to eq([ :tool_use, "tu_1", "do_thing", {"x" => 1} ])
    end

    it "builds a stream with chunks and an accumulated message" do
      stream = described_class.stream(text_chunks: [ "a", "b" ], message: described_class.message([]))
      expect(stream.text).to eq([ "a", "b" ])
      expect(stream.accumulated_message.content).to eq([])
    end
  end

  describe LlmMock::Anthropic::Provider do
    subject(:provider) { described_class.new }

    it "round-trips a tool_use message through serialize/deserialize" do
      sdk = SdkMessage.new([ SdkBlock.new("tool_use", nil, "tu_1", "emit", {"k" => "v"}) ])

      data = provider.serialize(:create, sdk)
      expect(data["tool_uses"]).to eq([ {"id" => "tu_1", "name" => "emit", "input" => {"k" => "v"}} ])

      block = provider.deserialize(:create, data).content.first
      expect([ block.type, block.name, block.input ]).to eq([ :tool_use, "emit", {"k" => "v"} ])
    end

    it "round-trips a stream, preserving text chunks" do
      sdk = SdkStream.new([ "one ", "two" ], SdkMessage.new([ SdkBlock.new("text", "one two") ]))

      data = provider.serialize(:stream, sdk)
      expect(data["text_chunks"]).to eq([ "one ", "two" ])

      replayed = provider.deserialize(:stream, data)
      expect(replayed.text).to eq([ "one ", "two" ])
      expect(replayed.accumulated_message.content.first.text).to eq("one two")
    end

    it "build_client routes SDK methods through the responder and call_real invokes the live client" do
      seen = []
      client = provider.build_client {|method, kwargs| seen << [ method, kwargs ]; :ok }

      expect(client.messages.create(model: "m", messages: [])).to eq(:ok)
      expect(client.messages.stream(model: "m")).to eq(:ok)
      expect(seen).to eq([ [ :create, {model: "m", messages: []} ], [ :stream, {model: "m"} ] ])

      real = SdkMessage.new([])
      live = Object.new
      live.define_singleton_method(:messages) { self }
      live.define_singleton_method(:create) {|**| real }
      expect(provider.call_real(live, :create, {model: "m"})).to be(real)
    end

    it "reads the system prompt for prompt_for" do
      expect(provider.prompt_for(system: "be terse")).to eq("be terse")
    end
  end
end
