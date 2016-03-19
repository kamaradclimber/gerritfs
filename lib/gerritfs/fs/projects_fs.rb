module GerritFS
  class ProjectsFS
    extend Cache

    def initialize(gerrit)
      @gerrit = gerrit
    end

    def clones
      @clones ||= {}
      @clones
    end

    def projects
      @projects = @gerrit.projects
      @projects
    end
    cache :projects, 10

    def elements
      @elements ||= projects.each_with_object({}) do |pair, mem|
        name, _project = pair
        url = @gerrit.clone_url_for(name)
        mem[name.tr('/', '_')] = ClonedProjectFS.new(@gerrit, url)
      end
    end

    include CompositionFS
  end
end
