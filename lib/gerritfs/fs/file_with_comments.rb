require_relative 'comment'

module GerritFS
  class FileWithComments
    def initialize(filename, content, comments, draft_comments)
      @filename = filename
      @content =  content.lines
      @comments = comments.map { |c| CommentInfo.new(c) }
      @draft_comments = draft_comments.map { |c| DraftCommentInfo.new(c) }

      # cleaning BOM markers otherwise size is wrong and the last char is truncated
      @content[0] = @content[0].gsub(/^\u{feff}/,'') unless @content.empty?
    end
    def to_s
      format.join
    end

    def each
      format.each
    end

    private

    def build_overlay
      comment_overlay = [nil].cycle.take(@content.size)
      (@comments + @draft_comments).group_by { |c| c['line'] }.
        each do |line, cs|
        comment_overlay[line -1] = cs.
          sort_by { |c| c['updated'] }
      end
      comment_overlay
    end

    def format
      comment_overlay = build_overlay
      @content.zip(comment_overlay).map do |l,cs|
        if cs then
          [l] + cs
        else
          l
        end
      end.flatten
    end
  end
end
