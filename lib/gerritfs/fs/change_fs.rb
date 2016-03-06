require 'cgi'
require_relative 'comment'
require_relative 'draft_comment'
require_relative 'file_with_comments'

module GerritFS
  class ChangeFS

    extend Cache

    def initialize(gerrit, id)
      @gerrit = gerrit
      @id     = id
    end

    META_FILES = [
      "COMMIT_MSG",
    ]

    def contents(path)
      current_revision = change['current_revision']
      files = change['revisions'][current_revision]['files'].keys.map { |k| sanitize(k) }

      diff_files = ["COMMIT_MSG", files].flatten.map do |file|
        %w(.a_ .b_).map { |p| p + file }
      end

      [files, diff_files, META_FILES].flatten
    end

    def file?(path)
      case path
      when '/'
        false
      else
        true
      end
    end

    def read_file(path)
      raise Errno::ENOENT.new(path) if path =~ /\.sw(x|p)$/

      content = get_file(path)
      case content
      when FileWithComments
        # ease readability
        content.to_s + "\n"
      else
        content.to_s
      end
    end

    # return an object representing the file content
    # string or FileWithComments
    def get_file(path)
      file = path[1..-1]
      case path
      when "/COMMIT_MSG"
        commit_file
      when "/.a_COMMIT_MSG"
        ""
      when "/.b_COMMIT_MSG"
        commit_file # TODO handle commit like a normal file (with comments for instance)
      when /\.(a|b)_(.*)$/
        filename    = file_from_sanitized($2)
        content = get_ab_file($2, $1)
        FileWithComments.new($2, $1, content, comments(filename), draft_comments(filename))
      else
        "Nothing in there, see .a_#{file} and .b_#{file}\n"
      end
    end

    def can_write?(path)
      case path
      when /\.sw(x|p)$/ # temporary vim files
        false
      when /^\/\.b_/
        true
      else
        false
      end
    end

    def write_to(path, content)
      case path
      when /^\/\.b_/
        if content.empty?
          puts "Truncating #{path}, ignoring for now"
          return
        end
        write_comments(path, content)
      else
        raise "Cannot write in #{path}"
      end
    end

    private
    include Sanitize

    def change
      @gerrit.change(@id, %w(CURRENT_REVISION ALL_FILES))
    end
    cache :change, 10

    # return the content of the file before/after the change
    def get_ab_file(sanitized_name, a_or_b)
      file = file_from_sanitized(sanitized_name)
      puts "#{sanitized_name} => #{file}"
      diff = @gerrit.file_diff(@id, CGI.escape(file))
      diff['content'].map do |content|
        res = [
          content['ab'],
          content[a_or_b],
        ].compact
      end.flatten.join("\n")
    end
    cache :get_ab_file, 10

    # return the file name from a sanitized one
    # src_main_java_class.java returns src/main/java/class.java
    def file_from_sanitized(sanitized_name)
      current_revision = change['current_revision']
      change['revisions'][current_revision]['files'].keys.find { |k| sanitize(k) == sanitized_name }
    end

    # return the content of the commit as a file
    def commit_file
      c = @gerrit.commit(@id)
      file = []
      file += c['parents'].map do |parent|
        "Parent:        #{parent['commit'][0..6]} (#{parent['subject']})"
      end
      file += ['committer', 'author'].map do |t|
        [
          "#{t.capitalize}:     #{c[t]['name']} <#{c[t]['email']}>",
          "#{t.capitalize}Date: #{c[t]['date']}"
        ]
      end.flatten
      file << ""
      file << c['message']
      file.join("\n")
    end
    cache :commit_file, 10

    def comments(file)
      @gerrit.comments(@id)[file] || []
    end
    cache :comments, 10

    def draft_comments(file)
      @gerrit.draft_comments(@id)[file] || []
    end
    cache :draft_comments, 10

    def write_comments(path, content)
      comments = parse_comments(path, content)
      f = file_from_sanitized(path.gsub(/^\/.b_/, ''))
      puts "Would submit #{comments.size} comment drafts"
      comments.each do |line, draft|
        puts '---'
        puts "Would draft comment at line #{line}"
        puts draft.join
        puts '---'
        draft.save(@gerrit)
      end
    end

    def parse_comments(path, content)
      # cleaning BOM markers
      orig    = get_file(path)
      content = content.force_encoding("utf-8").gsub(/^\xEF\xBB\xBF/, '')
      f = file_from_sanitized(path.gsub(/^\/.b_/, ''))


      comments = Hash.new do |h,line|
        h[line] = DraftComment.new(@id, f, line)
      end
      orig_enum = orig.each
      new_enum  = content.lines.each
      current_line = 1 # represent line number of content without comments
      inner_enum = nil # represent enum when inside a complex structure (comments)
      # at the end of this loop, drafted comments are in "comments" hash, indexed by their "current_line"
      while true
        original_line = (orig_enum.peek rescue nil)
        new_line      = (new_enum.peek rescue nil) # this rescue does not seem to work
        if original_line.nil? && new_line.nil? # end
          break
        elsif new_line.nil? # very weird
          puts "Deleted line seems likely on line #{current_line}"
          puts "Original line: #{original_line.dump}"
          puts "Let's avoid infinite loop!"
          raise "One or more lines have been removed from the original file!"
        else
          case original_line
          when String # either new_line is identical or it is a new comment draft
            if original_line.to_s.chomp == new_line.to_s.chomp
              orig_enum.next
              new_enum.next
              current_line += 1
            else # this is a new comment draft
              puts "Adding comments on line #{current_line} (1)"
              puts new_line.dump
              comments[current_line - 1] << new_line
              new_enum.next
            end
          when CommentInfo
            allow_insertion = inner_enum.nil?
            identical_lines = [] if inner_enum.nil?
            inner_enum    ||= original_line.to_s.lines.each
            inner_line      = (inner_enum.peek rescue nil)
            if inner_line.nil? # we've reached end of existing comment
              inner_enum = nil # reset inner_enum
              orig_enum.next
            elsif new_line.to_s.chomp == inner_line.to_s.chomp
              new_enum.next
              inner_enum.next
              # Store lines unless this is the header "Comment by ...:"
              unless inner_line.chomp == original_line.header
                identical_lines << inner_line
              end
            elsif !original_line.is_a?(DraftCommentInfo) && allow_insertion # this is a new comment draft
              inner_enum = nil # reset inner_enum
              new_enum.next
              puts "Adding comments on line #{current_line} (2)"
              puts new_line.dump
              comments[current_line - 1] << new_line
            elsif original_line.is_a?(DraftCommentInfo) # we append the original comment draft
              orig_enum.next
              inner_enum = nil # reset inner_enum
              new_enum.next
              puts "Adding comments on line #{current_line} (3)"
              puts new_line.dump
              identical_lines.each { |l| comments[current_line - 1] << l }
              comments[current_line - 1] << new_line
              comments[current_line - 1].id = original_line.id
            else # current comment has been modified
              raise "Current comment has been modified ?"
            end
          else
            raise "Not implemented #{original_line.class}"
          end
        end
      end
      comments
    end
  end
end
