module Asana
  class CLI
    attr_accessor :api_token, :options, :api, :args
    def initialize
      @options = OpenStruct.new(show_completed: false, show_mine: false)

      @api = API.new(Asana.token)
    end


    def handle_default_scope
      valid_workspaces = Asana.workspaces.map(&:name)
      possible_scope = (args.first || "").downcase.strip
      scope = if valid_workspaces.include? possible_scope
                possible_scope
              else
                env = ENV['ASANA_WORKSPACE_PROJECT']
                if env
                  args.unshift env
                end
                env
              end
    end

    def finish
      id = args[1][/\d+/]
      Asana::Task.finish(id)
      puts "Task completed! #{id}"
      exit
    end

    def show_workspaces
      puts Asana.workspaces.map(&:name)
    end

    def find_by_workspace
      case
      when args.first.include?("/")
        find_by_workspace_and_project
      else
        find_by_workspace_only
      end
    end

    def find_by_workspace_only
      # get corresponding workspace object
      workspace = Asana::Workspace.find args.first
      abort "Workspace not found!" unless workspace

      # display all tasks in workspace
      tasks = workspace.tasks options.show_completed
      puts tasks unless tasks.empty?
      exit
    end

    def find_by_workspace_and_project
      wkspace, proj = args.first.split("/", 2)
      # get corresponding workspace
      workspace = Asana::Workspace.find wkspace
      abort "Workspace not found!" unless workspace

      # get corresponding project
      project = Asana::Project.find workspace, proj
      abort "Project not found!" unless project

      # display all tasks in project
      tasks = project.tasks options.show_completed, options.show_mine
      puts tasks unless tasks.empty?
      exit
    end

    def extract_assignee!
      assignee = args.find do |word|
                   word =~ /^@(\w+)$/
                 end

      if assignee
        args.delete assignee
        assignee[1..-1]
      else
        nil
      end
    end

    def extract_due_date!
      # extract due date, if any
      due = Chronic.parse(args.reverse.first(2).reverse.join(" "))
      if !due.nil? && !due.to_s.empty?
        date = due.to_s.split.first

        # penultimate word is part of the date or a stop word, so remove it
        if Chronic.parse(args.reverse[1]) || ["due", "on", "for"].include?(args.reverse[1].downcase)
          args.pop
        end

        # extract date from datetime and remove date from task name
        args.pop

        date
      end
    end

    def extract_workspace_and_project(scope)
      workspace, project = scope.split("/")
      [workspace, project]
    end

    def create_task_in_workspace(scope, task, due, assignee)
      # workspace task name: create task in that workspace
      workspace = Asana::Workspace.find scope

      # create task in workspace
      task_obj = Asana::Task.create workspace, task, assignee, due
      puts "Task created in #{workspace.name}!"
      puts task_obj.to_yaml
      exit
    end

    def create_task_in_workspace_and_project(scope, task, due, assignee)
      # workspace/project task name: create task in that workspace
      workspace, project = extract_workspace_and_project(scope)
      workspace = Asana::Workspace.find workspace

      # create task in workspace
      task = Asana::Task.create workspace, task, assignee, due

      # get corresponding project
      project = Asana::Project.find workspace, project
      abort "Project not found!" unless project

      # add task to project
      api.post "tasks/#{task['data']['id']}/addProject", { "project" => project.id }
      puts "Task created in #{workspace.name}/#{project.name}!"
      puts task.to_yaml
      exit
    end

    def create_task
      assignee = extract_assignee!
      scope = args.first
      due = extract_due_date!
      task  = args[1..-1].join(" ")

      method_args = [scope, task, due, assignee]

      if scope.include?("/")
        create_task_in_workspace_and_project(*method_args)
      else
        create_task_in_workspace(*method_args)
      end

    end

    # parse argumens
    def parse(args)
      # no arguments given
      opts = OptionParser.new do |opts|
        opts.on("-c", "--[no-]completed", "Show completed") do |v|
          options.show_completed = v
        end

        opts.on("-m", "--[not-]me", "Show me") do |v|
          me = api.get "users/me"
          options.show_mine = me["data"]["id"]
        end
      end.parse!(args)

      @args = args

      arg_count = args.length

      cmd = args.first

      case
      when cmd.nil?
        handle_default_scope
        find_by_workspace
      when cmd.downcase == "finish" then finish
      when cmd.downcase == "workspaces"
        show_workspaces
      when cmd == "link"
        #TODO open on web or at least paste link
      when arg_count <= 1
        # Query workspace or wkspace/project
        handle_default_scope
        find_by_workspace
      else # arg_count > 1
        # Create task
        handle_default_scope
        create_task
      end
    end
  end
end
