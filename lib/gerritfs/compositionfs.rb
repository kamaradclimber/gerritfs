module GerritFS
  module CompositionFS

    # expect a elements method returning a map of file systems and their prefix

    def forward(path, root_value, method)
      puts self.class.to_s +  '|' + method.to_s + '|' + path
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
          puts "Forward to #{sub_fs[1]} with path #{sub_path}"
          return sub_fs[1].send(method, sub_path)
        else
          raise "No match for #{path}"
        end
      end
    end

    def contents(path)
        forward(path,
                elements.keys.map { |s| s.to_s},
                __method__)
    end
    
    def directory?(path)
      !file?(path)
    end

    def file?(path)
      forward(path, false, __method__)
    end

    def read_file(path)
      forward(path, "", __method__)
    end

  end
end
