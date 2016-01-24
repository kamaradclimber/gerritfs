module GerritFS
  class ChangesFS
    def initialize(gerrit, project)
      @gerrit = gerrit
      @project = project
    end

    def changes
      # todo add clever caching
      @gerrit.changes("q=project:#{@project}")
    end

    def contents(path)
      changes.map { |c| c['subject'] }
    end

    def file?(path)
      if path == '/'
        false
      else
        true
      end
    end
  end
end
