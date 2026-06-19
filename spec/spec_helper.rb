# frozen_string_literal: true

require "llm_mock_anthropic"

RSpec.configure do |config|
  config.expect_with(:rspec) {|c| c.syntax = :expect }
  config.disable_monkey_patching!
end

# A stand-in for the Anthropic SDK response objects, shaped like the gem's own
# structs, used to drive serialize without the real SDK.
SdkBlock = Struct.new(:type, :text, :id, :name, :input)
SdkMessage = Struct.new(:content)
SdkStream = Struct.new(:text, :accumulated_message)
