require 'mixlib/cli'
require 'fog-prune/config'

class FogPrune

  class Options
    include Mixlib::CLI

    option(:config,
      :short => '-c PATH',
      :long => '--config-file PATH',
      :description => 'JSON configuration file'
    )
    option(:fog_credentials,
      :short => '-f KEY=VALUE[,KEY=VALUE,...]',
      :long => '--fog-credentials KEY=VALUE[,KEY=VALUE,...]',
      :description => 'Fog credentials',
      :proc => lambda {|val|
        pairs = val.split(',').map{|v| v.split('=').map(&:strip) }
        provider = pairs.detect do |ary|
          ary.first == 'provider'
        end.last
        raise 'Credentials must include `provider`' unless provider
        FogPrune::Config[:fog][provider] ||= []
        FogPrune::Config[:fog][provider].push(Mash[*pairs.flatten]).uniq!
      }
    )
    option(:prune,
      :short => '-a sensu,chef',
      :long => '--apply-to sensu,chef',
      :description => 'Apply pruning to these items',
      :proc => lambda {|v| v.split(',')}
    )
    option(:chef_converge_every,
      :short => '-r SECS',
      :long => '--converge-recur SECS',
      :description => 'Number of seconds between convergences',
      :default => 3600
    )
    option(:sensu_host,
      :short => '-h HOST',
      :long => '--sensu-host HOST',
      :description => 'Hostname of sensu API'
    )
    option(:sensu_port,
      :short => '-p PORT',
      :long => '--sensu-port PORT',
      :description => 'Port of sensu API',
      :default => 4567,
      :proc => lambda {|v| v.to_i }
    )
    option(:sensu_username,
      :short => '-u USERNAME',
      :long => '--sensu-username USERNAME',
      :description => 'Sensu API username'
    )
    option(:sensu_password,
      :short => '-P PASSWORD',
      :long => '--sensu-password PASSWORD',
      :description => 'Sensu API password'
    )
    option(:nodes,
      :short => '-n NODE[,NODE...]',
      :long => '--nodes NODE[,NODE...]',
      :description => 'List of nodes to prune',
      :proc => lambda {|val|
        val.split(',').map(&:strip)
      }
    )
    option(:filter,
      :short => '-f "Solr filter"',
      :long => '--filter "Solr filter"',
      :description => 'Add filter to node search'
    )
    option(:debug,
      :short => '-d',
      :long => '--debug',
      :description => 'Turn on debug output'
    )

    option(:print_only,
      :short => '-o',
      :long => '--[no-]print-only',
      :boolean => true,
      :default => false,
      :description => 'Print action and exit'
    )

    def configure(args)
      parse_options(args)
      Config.merge!(config)
      Config[:debug] = true if Config[:print_only]
      Config.load_config_file! if Config[:config]
    end
  end
end
