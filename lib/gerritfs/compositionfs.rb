module GerritFS
  module CompositionFS
    # expect a elements method returning a map of file systems and their prefix

    def contents(path, opts = {})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path,
              elements.keys.map(&:to_s),
              __method__, opts)
    end

    def directory?(path, _opts = {})
      !file?(path)
    end

    def file?(path, opts = {})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, false, __method__, opts)
    end

    def read_file(path, opts = {})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, '', __method__, opts)
    end

    def can_write?(path, opts = {})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, false, __method__, opts)
    end

    def write_to(path, content, opts = {})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, false, __method__, opts, content)
    end

    private

    def forward(path, root_value, method, *my_args)
      opts, extra_args = my_args
      # indent = '..' * opts[:indentation]
      # $stderr.puts "#{indent}#{self.class}|#{method}|#{path}"
      case path
      when '/', '/._rfuse_check_'
        root_value
      else
        # Find shortest matching filesystem
        sub_fs = elements.map do |prefix, fs|
          path =~ %r{^/#{prefix}(.*)$} ? [Regexp.last_match(1), fs] : nil
        end.compact.sort_by { |prefix, _| prefix.size }.first

        # TODO: raise correct exception: Errno...)
        raise "No match for #{path}" unless sub_fs

        sub_path = sub_fs.first.empty? ? '/' : sub_fs.first
        # $stderr.puts "#{indent}Forward to #{sub_fs[1]} with path #{sub_path}"
        args = [sub_path]
        args += Array(extra_args) if extra_args
        args << opts if sub_fs[1].class.include?(CompositionFS)
        sub_fs[1].send(method, *args)
      end
    end
  end
end
