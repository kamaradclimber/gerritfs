module GerritFS
  class DraftComment
    extend Forwardable
    def_delegators :@lines, :<<, :join

    attr_accessor :id

    def initialize(review_id, revision, file, line)
      @lines     = []
      @review_id = review_id
      @revision  = revision
      @file      = file
      @line      =line
    end

    def save(client)
      if id
        client.update_draft_comment(@review_id, @file, id, @line, join, @revision)
      else
        client.create_draft_comment(@review_id, @file, @line, join, @revision)
      end
    end
  end
end
