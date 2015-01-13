##
# Asana API library and command-line client
# Tommy MacWilliam <tmacwilliam@cs.harvard.edu>
##

require "json"
require "net/https"
require "yaml"
# TODO replace with Time?
require "chronic"

%w[project task user workspace].each do |req|
  require_relative req
end

module Asana
  API_URL = "https://app.asana.com/api/1.0/"
  @show_completed = false
  @show_mine = false

  # initialize config values
  def self.init
    begin
      @@config = ENV.fetch('ASANA_API_TOKEN') do
        YAML.load_file(File.expand_path "~/.asana-client")["api-key"]
      end

    rescue
      abort "Configuration file could not be found.\nSee https://github.com/tmacwill/asana-client for installation instructions."
    end
  end

  # parse argumens
  def self.parse(args)
    # no arguments given
    if args.empty?
      abort "Nothing to do here."
    end

    if args.include? "-c"
      @show_completed = true
      args = args - ["-c"]
    end

    if args.include? "-m"
      me = Asana.get "users/me"
      @show_mine = me["data"]["id"]
      args = args - ["-m"]
    end

    # concatenate array into a string
    string = args.join " "

    # finish n: complete the task with id n
    if string =~ /^finish (\d+)$/
      Asana::Task.finish $1
      puts "Task completed!"
      exit
    end

    scope = args.shift
    string = args.join " "

    # workspace: display tasks in that workspace
    if args.length == 0 and scope =~ /^([^\/]+)$/
      # get corresponding workspace object
      workspace = Asana::Workspace.find $1
      abort "Workspace not found!" unless workspace

      # display all tasks in workspace
      tasks = workspace.tasks @show_completed
      puts tasks unless tasks.empty?
      exit
    end

    # workspace/project: display tasks in that project
    if args.length == 0 and scope =~ /^([^\/]+)\/(.+)$/
      # get corresponding workspace
      workspace = Asana::Workspace.find $1
      abort "Workspace not found!" unless workspace

      # get corresponding project
      project = Asana::Project.find workspace, $2
      abort "Project not found!" unless project

      # display all tasks in project
      tasks = project.tasks @show_completed, @show_mine
      puts tasks unless tasks.empty?
      exit
    end

    # extract assignee, if any
    assignee = nil
    args.each do |word|
      if word =~ /^@(\w+)$/
        assignee = word[1..-1]
        args.delete word
      end
    end

    # extract due date, if any
    due = Chronic.parse(args.reverse[0..1].reverse.join(" "))
    if !due.nil? && due.to_s =~ /(\d+)-(\d+)-(\d+)/
      # penultimate word is part of the date or a stop word, so remove it
      if Chronic.parse(args.reverse[1]) || ["due", "on", "for"].include?(args.reverse[1].downcase)
        args.pop
      end

      # extract date from datetime and remove date from task name
      args.pop
      due = "#{$1}-#{$2}-#{$3}"
    end

    # reset string, because we modifed argv
    string = args.join " "

    # workspace task name: create task in that workspace
    if scope =~ /^([^\/]+)$/
      # get corresponding workspace
      workspace = Asana::Workspace.find $1

      # create task in workspace
      Asana::Task.create workspace, string, assignee, due
      puts "Task created in #{workspace.name}!"
      exit
    end

    # workspace/project task name: create task in that workspace
    if scope =~ /^([^\/]+)\/(.+)$/
      # get corresponding workspace
      workspace = Asana::Workspace.find $1

      # create task in workspace
      task = Asana::Task.create workspace, string, assignee, due

      # get corresponding project
      project = Asana::Project.find workspace, $2
      abort "Project not found!" unless project

      # add task to project
      Asana.post "tasks/#{task['data']['id']}/addProject", { "project" => project.id }
      puts "Task created in #{workspace.name}/#{project.name}!"
      exit
    end
  end

  # perform a GET request and return the response body as an object
  def self.get(url)
    http_request(Net::HTTP::Get, url, nil, nil)
  end

  # perform a PUT request and return the response body as an object
  def self.put(url, data, query = nil)
    http_request(Net::HTTP::Put, url, data, query)
  end

  # perform a POST request and return the response body as an object
  def self.post(url, data, query = nil)
    http_request(Net::HTTP::Post, url, data, query)
  end

  # perform an HTTP request to the Asana API
  def self.http_request(type, url, data, query)
    # set up http object
    uri = URI.parse API_URL + url
    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    # all requests are json
    header = {
      "Content-Type" => "application/json"
    }

    # make request
    req = type.new("#{uri.path}?#{uri.query}", header)
      req.basic_auth @@config, ''
    if req.respond_to?(:set_form_data) && !data.nil?
      req.set_form_data data
    end
    res = http.start { |http| http.request req  }

    # return request object
    JSON.parse(res.body)
  end

  # get all of the users workspaces
  def self.workspaces
    spaces = self.get "workspaces"

    # convert array to hash indexed on workspace name
    spaces["data"].map do |space|
      Workspace.new :id => space["id"], :name => space["name"]
    end
  end
end
