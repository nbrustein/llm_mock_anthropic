# frozen_string_literal: true

require "llm_mock"
require "llm_mock_anthropic/version"

module LlmMock
  # Fabricates Anthropic Ruby SDK response objects for tests, and serializes them
  # to/from the plain hashes a cache stores.
  #
  # `LlmMock::Anthropic` is the namespace: the response structs and the builder
  # helpers live here, and `LlmMock::Anthropic::Provider` is the object a
  # consumer (e.g. deja) drives. Use `::Anthropic` for the SDK constant — bare
  # `Anthropic` inside this module would resolve to here.
  module Anthropic
    # Value objects shaped like what the SDK returns. App code reads `.content`
    # on a message, the block fields on each block, and `.text` /
    # `.accumulated_message` on a stream — these provide exactly that surface.
    TextBlock = Struct.new(:type, :text)
    ToolUseBlock = Struct.new(:type, :id, :name, :input)
    Message = Struct.new(:content)
    Stream = Struct.new(:text, :accumulated_message)

    # Ergonomic builders for canned responses — handy in specs that stub the
    # client directly and return a scripted response.
    #
    #   LlmMock::Anthropic.message([
    #     LlmMock::Anthropic.text("Here's the idea."),
    #     LlmMock::Anthropic.tool_use(id: "tu_1", name: "do_thing", input: {"x" => 1}),
    #   ])
    def self.text(text)
      TextBlock.new(:text, text)
    end

    def self.tool_use(id:, name:, input:)
      ToolUseBlock.new(:tool_use, id, name, input)
    end

    def self.message(blocks)
      Message.new(blocks)
    end

    def self.stream(text_chunks:, message:)
      Stream.new(text_chunks, message)
    end

    # Drives the Anthropic SDK shape for a consumer like deja: builds the stub
    # client, invokes the real client, and (de)serializes responses.
    class Provider < LlmMock::Provider
      def build_client(&responder)
        messages = Object.new
        messages.define_singleton_method(:create) {|**kwargs| responder.call(:create, kwargs) }
        messages.define_singleton_method(:stream) {|**kwargs| responder.call(:stream, kwargs) }

        client = Object.new
        client.define_singleton_method(:messages) { messages }
        client
      end

      def call_real(client, method, kwargs)
        client.messages.public_send(method, **kwargs)
      end

      def default_real_client
        -> { ::Anthropic::Client.new }
      end

      def prompt_for(kwargs)
        kwargs[:system].to_s
      end

      def serialize(method, response)
        method == :stream ? serialize_stream(response) : serialize_message(response)
      end

      def deserialize(method, data)
        method == :stream ? deserialize_stream(data) : deserialize_message(data)
      end

      private

      def serialize_message(message)
        build_response(message.content.map {|block| serialize_block(block) })
      end

      def serialize_stream(stream)
        build_response(
          stream.accumulated_message.content.map {|block| serialize_block(block) },
          text_chunks: stream.text.to_a,
        )
      end

      # The recorded `response` hash. `content` is what deserialize replays; the
      # `text_response`/`tool_uses` fields (and any consumer's summary) are
      # readable conveniences derived from it.
      def build_response(blocks, text_chunks: nil)
        text_blocks = blocks.select {|b| b["type"] == "text" }
        tool_use_blocks = blocks.select {|b| b["type"] == "tool_use" }

        response = {}
        response["text_response"] = text_blocks.map {|b| b["text"] }.join("\n") unless text_blocks.empty?
        unless tool_use_blocks.empty?
          response["tool_uses"] = tool_use_blocks.map do |b|
            {"id" => b["id"], "name" => b["name"], "input" => b["input"]}
          end
        end
        response["content"] = blocks
        response["text_chunks"] = text_chunks if text_chunks
        response
      end

      def serialize_block(block)
        case block.type.to_s
        when "tool_use"
          {"type" => "tool_use", "id" => block.id, "name" => block.name, "input" => block.input}
        else
          {"type" => block.type.to_s, "text" => block.text}
        end
      end

      def deserialize_message(data)
        Message.new(data["content"].map {|b| deserialize_block(b) })
      end

      def deserialize_block(data)
        case data["type"]
        when "tool_use"
          ToolUseBlock.new(:tool_use, data["id"], data["name"], data["input"])
        else
          TextBlock.new(data["type"].to_sym, data["text"])
        end
      end

      def deserialize_stream(data)
        blocks = (data["content"] || [ {"type" => "text", "text" => data["text_chunks"].join} ])
          .map {|b| deserialize_block(b) }
        Stream.new(data["text_chunks"].dup, Message.new(blocks))
      end
    end
  end
end
