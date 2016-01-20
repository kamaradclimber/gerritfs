module GerritFS
  class ChangesFS
    def initialize(gerrit, query)
      @gerrit = gerrit
      @query  = query
      @dashboard = DashboardFS.new(gerrit, query)
    end

    def elements
      {
        dashboard: @dashboard
      }
    end

    include CompositionFS


  end
end
