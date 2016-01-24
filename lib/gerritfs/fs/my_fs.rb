module GerritFS
  class MyFS
    def initialize(gerrit, query)
      @gerrit = gerrit
      @query  = query
      @dashboard = DashboardFS.new(gerrit, query)
    end

    def projects
      @projects = @gerrit.projects
      @projects # todo add clever caching
    end

    def elements
      @elements ||= projects.each_with_object({}) do |pair, mem|
        name, project = pair
        url = @gerrit.clone_url_for(name)
        mem[name.gsub('/', '_')] = ChangesFS.new(@gerrit, name)
      end
      @elements.merge({
        dashboard: @dashboard
      })
    end

    include CompositionFS
  end
end
