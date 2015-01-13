##
# Asana API library and command-line client
# Tommy MacWilliam <tmacwilliam@cs.harvard.edu>
#

require "json"
require "net/https"
require "yaml"
# TODO replace with Time?
require "chronic"

module Asana

    API_URL = "https://app.asana.com/api/1.0/"
    @show_completed = false
    @show_mine = false

    # initialize config values
    def self.init
        begin
            @@config = YAML.load_file File.expand_path "~/.asana-client"
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
        return Asana.http_request(Net::HTTP::Get, url, nil, nil)
    end

    # perform a PUT request and return the response body as an object
    def self.put(url, data, query = nil)
        return Asana.http_request(Net::HTTP::Put, url, data, query)
    end

    # perform a POST request and return the response body as an object
    def self.post(url, data, query = nil)
        return Asana.http_request(Net::HTTP::Post, url, data, query)
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
        req.basic_auth @@config["api_key"], ''
        if req.respond_to?(:set_form_data) && !data.nil?
            req.set_form_data data
        end
        res = http.start { |http| http.request req  }

        # return request object
        return JSON.parse(res.body)
    end

    # get all of the users workspaces
    def self.workspaces
        spaces = self.get "workspaces"
        list = []

        # convert array to hash indexed on workspace name
        spaces["data"].each do |space|
            list.push Workspace.new :id => space["id"], :name => space["name"]
        end

        list
    end

    class Project
        attr_accessor :id, :name, :workspace

        def initialize(hash)
            self.id = hash[:id] || 0
            self.name = hash[:name] || ""
            self.workspace = hash[:workspace] || nil
        end

        # search for a project within a workspace
        def self.find(workspace, name)
            # if given string for workspace, convert to object
            if workspace.is_a? String
                workspace = Asana::Workspace.find workspace
            end

            # check if any workspace contains the given name, and return first hit
            name.downcase!
            if workspace
                workspace.projects.each do |project|
                    if project.name.downcase.include? name
                        return project
                    end
                end
            end

            nil
        end

        # get all tasks associated with the current project
        def tasks(completed, mine)
            lookup = "tasks?project=#{self.id}"
            if mine
                # because we cannot filter on project & assignee
                lookup += "&opt_fields=name,assignee"
            end
            if not completed
                lookup += "&completed_since=now"
            end
            task_objects = Asana.get lookup
            list = []

            task_objects["data"].each do |task|
                if mine and (task["assignee"] == nil or task["assignee"]["id"] != mine)
                    next
                end

                list.push Task.new :id => task["id"], :name => task["name"],
                    :workspace => self.workspace, :project => self
            end

            list
        end
    end

    class Task
        attr_accessor :id, :name, :workspace, :project

        def initialize(hash)
            self.id = hash[:id] || 0
            self.name = hash[:name] || ""
            self.workspace = hash[:workspace] || nil
            self.project = hash[:project] || nil
        end

        # create a new task on the server
        def self.create(workspace, name, assignee = nil, due = nil)
            # if given string for workspace, convert to object
            if workspace.is_a? String
                workspace = Asana::Workspace.find workspace
            end
            abort "Workspace not found" unless workspace

            # if assignee was given, get user
            if !assignee.nil?
                assignee = Asana::User.find workspace, assignee
                abort "Assignee not found" unless assignee
            end

            # add task to workspace
            params = {
                "workspace" => workspace.id,
                "name" => name,
                "assignee" => (assignee.nil?) ? "me" : assignee.id
            }

            # attach due date if given
            if !due.nil?
                params["due_on"] = due
            end

            # add task to workspace
            Asana.post "tasks", params
        end

        # comment on a task
        def self.comment(id, text)
            Asana.post "tasks/#{id}/stories", { "text" => text }
        end

        # comment on the current task
        def comment(text)
            self.comment(self.id, text)
        end

        # finish a task
        def self.finish(id)
            Asana.put "tasks/#{id}", { "completed" => true }
        end

        # finish the current task
        def finish
            self.finish(self.id)
        end

        def to_s
            "(#{self.id}) #{self.name}"
        end
    end

    class User
        attr_accessor :id, :name

        def initialize(hash)
            self.id = hash[:id] || 0
            self.name = hash[:name] || ""
        end

        def self.find(workspace, name)
            # if given string for workspace, convert to object
            if workspace.is_a? String
                workspace = Asana::Workspace.find workspace
            end

            # check if any workspace contains the given name, and return first hit
            name.downcase!
            workspace.users.each do |user|
                if user.name.downcase.include? name
                    return user
                end
            end

            nil
        end

        def to_s
            self.name
        end
    end

    class Workspace
        attr_accessor :id, :name

        def initialize(hash)
            self.id = hash[:id] || 0
            self.name = hash[:name] || ""
        end

        # search a workspace by name
        def self.find(name)
            # check if any workspace contains the given name, and return first hit
            name.downcase!
            Asana.workspaces.each do |workspace|
                if workspace.name.downcase.include? name
                    return workspace
                end
            end

            nil
        end

        # get all projects associated with a workspace
        def projects
            project_objects = Asana.get "projects?workspace=#{self.id}"
            list = []

            project_objects["data"].each do |project|
                list.push Project.new :id => project["id"], :name => project["name"], :workspace => self
            end

            list
        end

        # get tasks within this workspace
        def tasks(completed)
            lookup = "tasks?workspace=#{self.id}"
            # -m can't be supported because the API requires that we
            # always set the assignee for workspaces.
            lookup += "&assignee=me"
            if not completed
                lookup += "&completed_since=now"
            end
            task_objects = Asana.get lookup
            list = []

            task_objects["data"].each do |task|
                list.push Task.new :id => task["id"], :name => task["name"],
                    :workspace => self
            end

            list
        end

        # get all users in the workspace
        def users
            user_objects = Asana.get "workspaces/#{self.id}/users"
            list = []

            user_objects["data"].each do |user|
                list.push User.new :id => user["id"], :name => user["name"]
            end

            list
        end
    end
end


if __FILE__ == $0
    Asana.init
    Asana.parse ARGV
end
