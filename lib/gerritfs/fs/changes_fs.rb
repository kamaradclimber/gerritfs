module GerritFS
  class ChangesFS
    def initialize(gerrit, query)
      @gerrit = gerrit
      @query  = query
    end

    def changes
      # todo add clever caching
      @changes = @gerrit.changes(@query).flatten
      @changes
    end

    def contents(path)
      changes.map { |c| c['subject'] }
    end

    def file?(path)
      true
    end

    def directory?(path)
      !file?(path)
    end
  end
end
