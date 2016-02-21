module GerritFS
  class MyFS

    extend Cache

    def initialize(gerrit, query)
      @gerrit = gerrit
      @query  = query
      @dashboard = DashboardFS.new(gerrit, query)
    end

    def projects
      @projects = @gerrit.projects
    end
    cache :projects, 10

    def elements
      @elements ||= projects.each_with_object({}) do |pair, mem|
        name, project = pair
        url = @gerrit.clone_url_for(name)
        mem[name.gsub('/', '_')] = ChangeListFS.new(@gerrit, name)
      end
      @elements.merge({
        dashboard: @dashboard
      })
    end

    include CompositionFS
  end
end
