module GerritFS
  class CommentInfo
    def initialize(c)
      @c = c
    end

    def [](key)
      @c[key]
    end

    def draft?
      false
    end

    def id
      @c['id']
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

  class DraftCommentInfo < CommentInfo
    def draft?
      true
    end

    def author
      'you'
    end
  end
end
