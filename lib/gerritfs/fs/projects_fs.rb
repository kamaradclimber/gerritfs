module GerritFS
  class ProjectsFS
    def initialize(gerrit)
      @gerrit = gerrit
    end

    def clones
      @clones ||= {}
      @clones
    end

    def projects
      @projects = @gerrit.projects
      @projects # todo add clever caching
    end

    def elements
      @elements ||= projects.each_with_object({}) do |pair, mem|
        name, project = pair
        url = @gerrit.clone_url_for(name)
        mem[name.gsub('/', '_')] = ClonedProjectFS.new(@gerrit, url)
      end
    end

    include CompositionFS
  end

end
