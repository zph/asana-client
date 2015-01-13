module Asana
  class Workspace
    attr_accessor :id, :name

    def initialize(hash)
      @id = hash[:id] || 0
      @name = hash[:name] || ""
    end

    # search a workspace by name
    def self.find(name)
      # check if any workspace contains the given name, and return first hit
      Asana.workspaces.find do |workspace|
        workspace.name.downcase.include? name.downcase
      end

      nil
    end

    # get all projects associated with a workspace
    def projects
      project_objects = Asana.get "projects?workspace=#{self.id}"

      project_objects["data"].map do |project|
        Project.new :id => project["id"], :name => project["name"], :workspace => self
      end
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

      task_objects["data"].map do |task|
        Task.new :id => task["id"], :name => task["name"], :workspace => self
      end
    end

    # get all users in the workspace
    def users
      user_objects = Asana.get "workspaces/#{self.id}/users"

      user_objects["data"].map do |user|
        User.new :id => user["id"], :name => user["name"]
      end
    end
  end
end
