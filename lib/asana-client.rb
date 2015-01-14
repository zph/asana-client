##
# Asana API library and command-line client
# Tommy MacWilliam <tmacwilliam@cs.harvard.edu>
##

require "json"
require "net/https"
require "yaml"
require 'optparse'
require 'ostruct'

# TODO replace with Time?
require "chronic"

%w[project task user workspace cli api].each do |req|
  require_relative "asana-client/#{req}"
end

module Asana
  class << self
    def token
      @token ||= begin
        ENV.fetch('ASANA_API_TOKEN') do
          YAML.load_file(File.expand_path "~/.asana-client")["api-key"]
        end
      rescue
        abort "Configuration file could not be found.\nSee https://github.com/tmacwill/asana-client for installation instructions."
      end
    end

    def api
      @api ||= API.new(token)
    end

    # get all of the users workspaces
    def workspaces
      api.get("workspaces")["data"].map do |space|
        id, name = space.values_at("id", "name")
        Workspace.new :id => id, :name => name
      end
    end
  end
end
