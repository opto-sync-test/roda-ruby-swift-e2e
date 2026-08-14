require "json"
require "roda"

require_relative "syncer"

class SyncApp < Roda
  plugin :json

  route do |request|
    request.get "health" do
      {status: "ok", core_version: OptoSync.version}
    end

    request.post "merge" do
      payload = JSON.parse(request.body.read)
      {
        merged: OptoSync.merge(payload.fetch("base"), payload.fetch("incoming")),
        core_version: OptoSync.version
      }
    end
  end
end
