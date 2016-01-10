require "gerritfs/version"
require "gerritfs/gerrit/client"

require 'rfusefs'
require 'tmpdir'

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

  class ClonedProjectFS
    def initialize(gerrit, clone_url)
      @gerrit = gerrit
      @clone_url = clone_url
      @temp = Dir.mktmpdir
      puts "Cloning #{clone_url} in #{@temp}"
      cmd = "git clone --depth 5 #{clone_url} #{@temp}"
      puts cmd
      begin
      `git clone --depth 5 #{clone_url} #{@temp}`
      rescue => e
        puts e
      end
    end

    def contents(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path

      prefix = File.join(@temp, path)
      Dir[File.join(prefix, '*')].map do |file|
        file.gsub(prefix, '')
      end
    end

    def file?(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      puts File.join(@temp, path)
      File.file?(File.join(@temp, path))
    end

    def directory?(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      File.directory?(File.join(@temp, path))
    end

  end

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
      else # forward to clone
        project = projects[subs.join('/')]
        raise "Unknown project #{subs.join('/')}" unless project
        clone = @gerrit.clone_url_for(subs.take(2).join('/'))
        clones[path] ||= ClonedProjectFS.new(@gerrit, clone)
        clones[path].contents(subs.drop(2).join('/'))

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
        false
      else
        clone = @gerrit.clone_url_for(subs.take(2).join('/'))
        clones[path] ||= ClonedProjectFS.new(@gerrit, clone)
        clones[path].file?(subs.drop(2).join('/'))
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
