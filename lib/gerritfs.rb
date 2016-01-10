require "gerritfs/version"
require "gerritfs/gerrit/client"

require 'rfusefs'

module GerritFS
  class BaseFS
    def initialize(opts)
      client    = Gerrit::Client.new(opts)
      @projects = ProjectsFS.new(client)
      @my       = ChangesFS.new(client, 'q=is:open+owner:self&q=is:open+reviewer:self+-owner:self&q=is:closed+owner:self+limit:5')
    end

    def contents(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      case path
      when '/'
        [ 'my', 'projects' ]
      when /\/projects(.*)/
        @projects.contents($1)
      when /\/my(.*)/
        @my.contents($1)
      else
        # should forward to sub FS
        raise "Not implemented yet #{path}"
      end
    end

    def file?(path)
      case path
      when '/'
        false
      when /\/projects\/(.*)/
        @projects.file?($1)
      when /\/my\/(.*)/
        @my.file?($1)
      when '/my', '/projects'
        false
      else
        # should forward to sub FS
        raise "Not implemented yet #{path}"
      end
    end

    def directory?(path)
      !file?(path)
    end

  end

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

  class ProjectsFS
    def initialize(gerrit)
      @gerrit = gerrit
    end

    def projects
      @projects = @gerrit.projects
      @projects # todo add clever caching
    end

    def contents(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      subs = path.gsub(/^\//,'').split('/')
      puts "Size #{subs.size}"
      case subs.size
      when 0
        projects.keys.map { |full| full.split('/')[0] }.uniq
      when 1
        projects.keys.
          select { |full| full =~ /^#{subs.first}\//}.
          map    { |full| full.split('/')[1] }.compact.uniq
      else
        raise "Not supported yet #{path}"
      end
    end

    def file?(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      subs = path.gsub(/^\//,'').split('/')
      puts "Size #{subs.size}"
      case subs.size
      when 0,1
        false
      when 2
        true
      end
    end

    def directory(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      !file?(path)
    end

    def read_file(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      projects[path]
    end
  end

end
