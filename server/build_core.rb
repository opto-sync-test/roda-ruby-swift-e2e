require "fileutils"
require "rbconfig"

root = File.expand_path("..", __dir__)
core = File.join(root, "vendor", "opto-sync-clients", "syncer.c", "core")
output_directory = File.join(root, ".build")
FileUtils.mkdir_p(output_directory)

case RbConfig::CONFIG.fetch("host_os")
when /darwin/
  output = File.join(output_directory, "libsyncer.dylib")
  linker = "-dynamiclib"
when /linux/
  output = File.join(output_directory, "libsyncer.so")
  linker = "-shared"
else
  abort "unsupported host OS: #{RbConfig::CONFIG.fetch("host_os")}"
end

command = [
  RbConfig::CONFIG.fetch("CC"),
  "-std=c11",
  "-O2",
  "-fPIC",
  linker,
  "-I#{File.join(core, "include")}",
  File.join(core, "src", "syncer.c"),
  File.join(core, "src", "yyjson.c"),
  "-o",
  output
]

abort "failed to compile syncer.c" unless system(*command)
puts output
