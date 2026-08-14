require "json"
require "minitest/autorun"
require "rack/test"

require_relative "../app"

class SyncAppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    SyncApp.app
  end

  def test_roda_merges_with_the_pinned_core
    post(
      "/merge",
      JSON.generate(
        base: {
          id: "doc-1",
          profile: {server: "kept"},
          items: [{id: "a", server: true}]
        },
        incoming: {
          profile: {client: "kept"},
          items: [{id: "a", client: true}]
        }
      ),
      "CONTENT_TYPE" => "application/json"
    )

    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_match(/^\d+\.\d+\.\d+$/, body.fetch("core_version"))
    assert_equal(
      {"server" => "kept", "client" => "kept"},
      body.dig("merged", "profile")
    )
    assert_equal(
      [{"id" => "a", "server" => true, "client" => true}],
      body.dig("merged", "items")
    )
  end
end
