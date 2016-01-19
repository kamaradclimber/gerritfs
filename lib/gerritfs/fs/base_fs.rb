module GerritFS
  class BaseFS
    def initialize(opts)
      client    = Gerrit::Client.new(opts)
      @projects = ProjectsFS.new(client)
      @my       = ChangesFS.new(client, 'q=is:open+owner:self&q=is:open+reviewer:self+-owner:self&q=is:closed+owner:self+limit:5')
    end

    def elements
      {
        projects: @projects,
        my:       @my,
      }
    end

    include CompositionFS
  end
end
