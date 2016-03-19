module GerritFS
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

    def real(path)
      puts 'Real path ' + File.join(@temp, path)
      File.join(@temp, path)
    end

    # clones are non-writable
    def can_write?(_path)
      false
    end

    def contents(path)
      clone!
      puts self.class.to_s + '|' + __method__.to_s + '|' + path

      prefix = real(path)
      Dir[File.join(prefix, '*')].map do |file|
        file.gsub(prefix, '').gsub(/^\//, '')
      end
    end

    def file?(path)
      return false if path == '/' # avoid clone
      clone!
      puts self.class.to_s + '|' + __method__.to_s + '|' + path
      File.file?(real(path))
    end

    def directory?(path)
      clone!
      puts self.class.to_s + '|' + __method__.to_s + '|' + path
      File.directory?(real(path))
    end

    def read_file(path)
      clone!
      puts self.class.to_s + '|' + __method__.to_s + '|' + path
      File.read(real(path))
    end
  end
end
