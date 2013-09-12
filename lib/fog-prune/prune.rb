require 'fog'
require 'chef'
require 'chef/knife'
require 'chef/knife/core/ui'

require 'fog-prune/config'
require 'fog-prune/options'

class FogPrune

  PROVIDER_ALIASES = Mash.new(
    :ec2 => 'aws'
  )

  attr_reader :ui

  def initialize
    Chef::Knife.new.configure_chef
    @compute = Mash.new
    @ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
  end

  def compute(provider)
    p_key = PROVIDER_ALIASES[provider] || provider
    unless(@compute[p_key])
      raise "No Fog credentials provided for #{provider}!" unless Config[:fog][p_key]
      @compute[p_key] = []
      @compute[p_key] = Config[:fog][p_key].map do |args|
        Fog::Compute.new(
          format_fog_hash(args)
        )
      end
    end
    @compute[p_key]
  end

  def format_fog_hash(hash)
    new_hash = {}
    hash.each do |k,v|
      new_hash[k.to_sym] = v
    end
    new_hash
  end

  def sensu?
    Config[:prune].include?('sensu')
  end

  def chef?
    Config[:prune].include?('chef')
  end

  def prune!
    ui.info "Starting node pruning..."
    ui.warn "Pruning from: #{Config[:prune].join(', ')}"
    nodes_to_prune = discover_prunable_nodes
    debug "Initial nodes discovered: #{nodes_to_prune.map(&:name).sort.join(', ')}"
    debug "Initial node count: #{nodes_to_prune.size}"
    nodes_to_prune = filter_prunables_via_fog(nodes_to_prune)
    ui.warn "Nodes to prune: #{nodes_to_prune.size}"
    debug "#{nodes_to_prune.map(&:name).sort.join(', ')}"
    unless(Config[:print_only])
      ui.confirm('Destroy these nodes')
      nodes_to_prune.each do |node|
        prune_node(node)
      end
    end
  end

  def discover_prunable_nodes
    if(Config[:nodes])
      query = Array(Config[:nodes]).flatten.map do |name|
        "name:#{name}"
      end.join(' OR ')
    else
      max_ohai_time = Time.now.to_f - Config[:chef_converge_every].to_f
      query = ["ohai_time:[0.0 TO #{max_ohai_time}]"]
      if(Config[:filter])
        query << Config[:filter]
      end
    end
    Chef::Search::Query.new.search(:node, query.join(' AND ')).first
  end

  def prune_node(node)
    prune_sensu(node) if sensu?
    prune_chef(node) if chef?
  end

  def prune_sensu(node)
    debug "Pruning node from sensu server: #{node.name}"
    url = "http://#{args[:sensu][:host]}:#{args[:sensu][:port]}" <<
      "/clients/#{node.name}"
    begin
      timeout(30) do
        RestClient::Resource.new(
          api_url,
          :user => args[:sensu][:username],
          :password => args[:sensu][:password]
        ).delete
      end
    rescue => e
      puts "Failed to remove #{node.name} - Unexpected error: #{e}"
    end
  end

  def prune_chef(node)
    debug "Pruning node from chef server: #{node.name}"
    node.destroy
    Chef::ApiClient.load(node.name).destroy
  end

  def filter_prunables_via_fog(nodes_to_prune)
    nodes_to_prune.map do |node|
      if(node.cloud && node.cloud.provider)
        if(respond_to?(check_method = "#{node.cloud.provider}_check"))
          send(check_method, node) ? node : nil
        end
      end
    end.compact
  end

  ## Checks

  def ec2_check(node)
    aws_node = ec2_nodes.detect{|n| n.id == node.ec2.instance_id}
    unless(aws_node)
      debug "#{node.name} returned nil from aws"
    else
      debug "#{node.name} state on aws: #{aws_node.state}"
    end
    aws_node.nil? || aws_node.state == 'terminated'
  end

  def ec2_nodes
    unless(@ec2_nodes)
      @ec2_nodes = compute(:aws).map do |compute_con|
        compute_con.servers.all
      end.flatten
    end
    @ec2_nodes
  end

  def rackspace_check(node)
    raise 'Not implemented'
  end

  def debug(msg)
    ui.info "#{ui.color('[DEBUG]', :magenta)} #{msg}" if Config[:debug]
  end
end
