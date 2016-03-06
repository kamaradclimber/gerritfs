module GerritFS
  class Comment
    def initialize(c)
      @c = c
    end

    def [](key)
      @c[key]
    end

    def draft?
      false
    end

    def author
      @c['author']['name']
    end

    def header
      "Comment by #{author} #{draft? ? '(draft)' : ''}:"
    end

    def to_s
      <<-EOH.gsub(/^\s+/,'')
      #{header}
      #{@c['message']}
      EOH
    end
  end

  class DraftComment < Comment
    def draft?
      true
    end

    def author
      'you'
    end
  end
end
