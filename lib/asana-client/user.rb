module Asana
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
      workspace.users.find do |user|
        user.name.downcase.include? name
      end

      nil
    end

    def to_s
      self.name
    end
  end
end
