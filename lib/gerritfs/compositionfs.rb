module GerritFS
  module CompositionFS

    # expect a elements method returning a map of file systems and their prefix

    def forward(path, root_value, method)
      puts self.class.to_s +  '|' + method.to_s + '|' + path
      case path
      when '/'
        root_value
      else
        elements.each do |prefix, fs|
          match = /^\/#{prefix}(.*)$/
          if path =~ match
            sub_path = $1.empty? ? '/' : $1
            puts "Forward to #{fs} with path #{sub_path}"
            return fs.send(method, sub_path)
          end
        end
        raise "No match for #{path}"
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
  end
end
