module GerritFS
  class DraftComment
    extend Forwardable
    def_delegators :@lines, :<<, :join

    attr_accessor :id

    def initialize(review_id, file, line)
      @lines     = []
      @review_id = review_id
      @file      = file
      @line      =line
    end

    def save(client)
      if id
        client.update_draft_comment(@review_id, @file, id, @line, join)
      else
        client.create_draft_comment(@review_id, @file, @line, join)
      end
    end
  end
end
