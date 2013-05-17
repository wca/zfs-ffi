Dir["#{File.dirname(__FILE__)}/zfs/*.rb"].each do |path|
  name = File.basename(path, ".rb")
  require "zfs/#{name}"
end
