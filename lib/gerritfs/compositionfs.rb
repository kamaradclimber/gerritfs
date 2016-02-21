module GerritFS
  module CompositionFS

    # expect a elements method returning a map of file systems and their prefix

    def forward(path, root_value, method, opts)
      indent = ".." * opts[:indentation]
      $stderr.puts "#{indent}#{self.class}|#{method}|#{path}"
      case path
      when '/'
        root_value
      else
        sub_fs = elements.map do |prefix, fs|
          if path =~ /^\/#{prefix}(.*)$/
            [ $1, fs ]
          else
            nil
          end
        end.compact.sort_by do |prefix, fs|
          prefix.size
        end.first
        if sub_fs
          sub_path = sub_fs[0].empty? ? '/' : sub_fs[0]
          $stderr.puts "#{indent}Forward to #{sub_fs[1]} with path #{sub_path}"
          if sub_fs[1].class.include?(CompositionFS)
            return sub_fs[1].send(method, sub_path, opts)
          else
            return sub_fs[1].send(method, sub_path)
          end
        else
          raise "No match for #{path}"
        end
      end
    end

    def contents(path, opts={})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path,
              elements.keys.map { |s| s.to_s},
              __method__, opts)
    end

    def directory?(path, opts={})
      !file?(path)
    end

    def file?(path, opts={})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, false, __method__, opts)
    end

    def read_file(path, opts={})
      opts[:indentation] = (opts[:indentation] || 0) + 1
      forward(path, "", __method__, opts)
    end

    private
    
  end
end
