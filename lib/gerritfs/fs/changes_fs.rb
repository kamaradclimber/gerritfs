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

    def elements
      @elements ||= {}
      changes.each do |c|
        @elements[c['subject']] ||= ChangeFS.new(@gerrit, c['id'])
      end
      @elements
    end

    include CompositionFS

  end
end
