module Asana
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

end
