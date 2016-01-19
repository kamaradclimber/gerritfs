require "gerritfs/version"
require "gerritfs/gerrit/client"
require "gerritfs/compositionfs"

require 'rfusefs'
require 'tmpdir'

module GerritFS
  class BaseFS
    def initialize(opts)
      client    = Gerrit::Client.new(opts)
      @projects = ProjectsFS.new(client)
      @my       = ChangesFS.new(client, 'q=is:open+owner:self&q=is:open+reviewer:self+-owner:self&q=is:closed+owner:self+limit:5')
    end

    def elements
      {
        projects: @projects,
        my:       @my,
      }
    end

    include CompositionFS
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
    end

    def clone!
      return true if @cloned
      puts "Cloning #{@clone_url} in #{@temp}"
      cmd = "git clone --depth 5 #{@clone_url} #{@temp}"
      puts cmd
      begin
      `git clone --depth 5 #{@clone_url} #{@temp}`
      @cloned = true
      rescue => e
        puts e
        raise
      end
    end

    def contents(path)
      clone!
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path

      prefix = File.join(@temp, path)
      puts "Real path " + prefix
      Dir[File.join(prefix, '*')].map do |file|
        file.gsub(prefix, '').gsub(/^\//,'')
      end
    end

    def file?(path)
      clone!
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      puts "Real path " + File.join(@temp, path)
      File.file?(File.join(@temp, path))
    end

    def directory?(path)
      clone!
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      puts "Real path " + File.join(@temp, path)
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

    def elements
      @elements ||= projects.each_with_object({}) do |pair, mem|
        name, project = pair
        url = @gerrit.clone_url_for(name)
        mem[name.gsub('/', '_')] = ClonedProjectFS.new(@gerrit, url)
      end
    end

    include CompositionFS

    def read_file(path)
      puts self.class.to_s +  '|' + __method__.to_s + '|' + path
      projects[path]
    end
  end

end
