module Asana
  class Project
    attr_accessor :id, :name, :workspace

    def initialize(hash)
      @id = hash[:id] || 0
      @name = hash[:name] || ""
      @workspace = hash[:workspace] || nil
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
        workspace.projects.map do |project|
          project.name.downcase.include? name.downcase
        end
      end
    end

    # get all tasks associated with the current project
    def tasks(completed, mine)
      lookup = "tasks?project=#{self.id}"
      if mine
        # because we cannot filter on project & assignee
        lookup += "&opt_fields=name,assignee"
      end

      if !completed
        lookup += "&completed_since=now"
      end

      task_objects = Asana.api.get lookup

      task_objects["data"].map do |task|
        if mine and (task["assignee"] == nil or task["assignee"]["id"] != mine)
          next
        end

        Task.new(:id => task["id"],
                 :name => task["name"],
                 :workspace => self.workspace,
                 :project => self)
      end

      list
    end
  end
end
