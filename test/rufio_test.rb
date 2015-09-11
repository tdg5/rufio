require "test_helper"

class RufioTest < Rufio::TestCase
  context "version" do
    should "be defined" do
      refute_nil ::Rufio::VERSION
    end
  end
end
