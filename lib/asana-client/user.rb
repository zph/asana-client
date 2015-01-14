module Asana
  class User
    attr_accessor :id, :name

    def initialize(hash)
      @id = hash.fetch(:id) { 0 }
      @name = hash.fetch(:name){ "" }
    end

    def self.find(workspace, name)
      # if given string for workspace, convert to object
      if workspace.is_a? String
        workspace = Asana::Workspace.find workspace
      end

      # check if any workspace contains the given name, and return first hit
      workspace.users.find do |user|
        user.name.downcase == name.downcase
      end
    end

    def to_s
      self.name
    end
  end
end
