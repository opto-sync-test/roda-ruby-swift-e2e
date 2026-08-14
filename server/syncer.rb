require "fiddle/import"
require "json"

module SyncerNative
  extend Fiddle::Importer

  default_library = if RUBY_PLATFORM.include?("darwin")
    File.expand_path("../.build/libsyncer.dylib", __dir__)
  else
    File.expand_path("../.build/libsyncer.so", __dir__)
  end

  dlload ENV.fetch("OPTO_SYNC_LIB", default_library)

  MergeOptions = struct([
    "void* override_cb",
    "int array_strategy",
    "uint32_t max_depth",
    "char detect_circular_refs",
    "char resolve_by_timestamp",
    "char* lww_keys",
    "char* fww_keys",
    "char* array_match_keys"
  ])

  extern "void* syncer_merge_json_ex(const char*, const char*, const void*)"
  extern "void syncer_free(void*)"
  extern "const char* syncer_version()"
end

module OptoSync
  module_function

  def version
    SyncerNative.syncer_version.to_s
  end

  def merge(base, incoming)
    lww_keys = Fiddle::Pointer["updatedAt,syncedAt\0"]
    match_keys = Fiddle::Pointer["id\0"]
    options = SyncerNative::MergeOptions.malloc
    options.override_cb = 0
    options.array_strategy = 4
    options.max_depth = 0
    options.detect_circular_refs = 0
    options.resolve_by_timestamp = 1
    options.lww_keys = lww_keys
    options.fww_keys = 0
    options.array_match_keys = match_keys

    result = SyncerNative.syncer_merge_json_ex(
      JSON.generate(base),
      JSON.generate(incoming),
      options
    )
    raise ArgumentError, "syncer.c rejected the merge input" if result.null?

    begin
      JSON.parse(result.to_s)
    ensure
      SyncerNative.syncer_free(result)
    end
  end
end
