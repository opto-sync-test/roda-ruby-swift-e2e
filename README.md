# Roda Ruby + Swift Opto-Sync E2E

This repository proves an official Swift client can cross a Ruby/Roda HTTP boundary and reconcile data with the exact Opto-Sync C core.

## What the test covers

- Ruby compiles the vendored `syncer.c` and `yyjson.c` sources into a native library;
- Roda calls the extended C API through Fiddle with the shared CRDT merge policy;
- the Swift package consumes the official `OptoSyncClient` package by local path;
- `URLSession` sends an actual authenticated JSON request to the Ruby server;
- nested objects and array elements matched by `id` retain independent server and client fields;
- both Ruby and Swift assertions verify the native engine version.

Swift also exposes a bounded `BackgroundSyncWorker` that drains iOS and macOS
lanes concurrently and replays the immutable batch if any response is lost.
An Apple-only adapter wires that operation into `BGTaskScheduler`, while the
worker core remains Foundation-only and is tested on the hosted Linux Swift
toolchain.

`vendor/opto-sync-clients` and its nested `syncer.c` repository are Git submodules. Their exact revisions are recorded in `opto-sync-pin.json`.

## Run locally

Prerequisites: Ruby 3.3+, Bundler, a C compiler, and Swift 5.9+.

```sh
git submodule update --init --recursive
cd server
bundle install
bundle exec ruby build_core.rb
bundle exec ruby -I. test/app_test.rb
bundle exec rackup --server webrick --host 127.0.0.1 --port 9292
```

With the Ruby server running, execute the Swift network test in another terminal:

```sh
swift test
```
