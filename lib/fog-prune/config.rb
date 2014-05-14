require 'chef/mash'
require 'mixlib/config'

class FogPrune

  class Config
    extend Mixlib::Config

    fog Mash.new
    chef_converge_every 3600
    prune []
    nodes nil
    debug false

    class << self
      def load_config_file!
        raise 'No config file path defined!' unless self[:config]
        raise 'No configuration file found at defined path!' unless File.exists?(self[:config])
        Mash.new(Chef::JSONCompat.from_json(File.read(self[:config]))).each do |k,v|
          self.send(k, v)
        end
        self
      end
    end
  end

end
