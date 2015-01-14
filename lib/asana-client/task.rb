module Asana
  class Task
    attr_accessor :id, :name, :workspace, :project

    def initialize(hash)
      @id         = hash[:id] || 0
      @name       = hash[:name] || ""
      @workspace  = hash[:workspace] || nil
      @project    = hash[:project] || nil
    end

    # create a new task on the server
    def self.create(workspace, name, assignee = nil, due = nil)
      # if given string for workspace, convert to object
      if workspace.is_a? String
        workspace = Asana::Workspace.find workspace
      end

      abort "Workspace not found" unless workspace

      # if assignee was given, get user
      if assignee
        assignee = Asana::User.find(workspace, assignee)
        abort "Assignee not found" unless assignee
      end

      params = {
        "workspace" => workspace.id,
        "name" => name,
        "assignee" => assignee.nil? ? "me" : assignee.id
      }

      if due
        params["due_on"] = due
      end

      Asana.api.post "tasks", params
    end

    # comment on a task
    def self.comment(id, text)
      Asana.api.post "tasks/#{id}/stories", { "text" => text }
    end

    # comment on the current task
    def comment(text)
      self.comment(self.id, text)
    end

    # finish a task
    def self.finish(id)
      Asana.api.put "tasks/#{id}", { "completed" => true }
    end

    # finish the current task
    def finish
      self.finish(self.id)
    end

    def to_s
      "#{self.id} - #{self.name}"
    end
  end

end
