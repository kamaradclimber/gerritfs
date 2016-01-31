module GerritFS
  class DashboardFS
    extend GerritFS::Cache

    def initialize(gerrit, query)
      @gerrit = gerrit
      @query  = query
    end

    def changes
      @changes = @gerrit.changes(@query).flatten
      @changes
    end
    cache :changes, 10

    def contents(path)
      raise "fsjfk"
    end

    def file?(path)
      true
    end

    def directory?(path)
      !file?(path)
    end

    def read_file(path)
      lines = changes.map do |c|
        [
          c['status'],
          c['project'],
          c['subject'],
          feedback(c).to_s,
        ]
      end
      tabulize(lines) + "\n"
    end

    private
    def feedback(change)
      short = {
        "Code-Review" =>    "CR",
        "Verified"    =>    "V",
        "Ready-to-Submit"=> "RTS",
      }
      change['labels'].map do |type, details|
        value   = "OK" if details['approved'] 
        value   = "NO" if details['rejected'] 
        if value.nil? && details['value']
          value   = details['value']
          value   = ((value > 0) ? '+' : '') + value.to_s
        end
        short[type] + ':' + value if value
      end.compact.join(', ')
    end

    def tabulize(array)
      # compute column sizes
      columns = array.inject(0) do |mem, el| [mem,el.size].max end
      column_sizes = array.inject( [0] * columns) do |mem, el|
        mem.zip(el).map do |max_column_size, column| [ max_column_size, column.size].max end
      end
      array.map do |line|
        line.zip(column_sizes).map do |value, size|
          "#{value}#{ " " * (size - value.size + 1)}"
        end.join
      end.join("\n")
    end

  end
end
