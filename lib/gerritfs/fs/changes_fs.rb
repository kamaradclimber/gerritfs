module GerritFS
  class ChangesFS

    extend Cache

    def initialize(gerrit, project)
      @gerrit = gerrit
      @project = project
    end

    def changes
      @gerrit.changes("q=project:#{@project}")
    end
    cache :changes, 10

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
