module GerritFS
  class ChangeListFS
    extend Cache

    def initialize(gerrit, project)
      @gerrit = gerrit
      @project = project
    end

    def changes # TODO: remove artificial limitation to 50 changes
      @gerrit
        .changes("q=project:#{@project}")
        .take(50)
    end
    cache :changes, 10

    def elements
      @elements ||= {}
      changes.each do |c|
        @elements[sanitize(c['subject'])] ||= ChangeFS.new(@gerrit, c['id'])
      end
      @elements
    end

    include CompositionFS

    private

    include Sanitize
  end
end
