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

    META_FILES = %w(
      COMMIT_MSG
      CURRENT_REVISION).freeze

    def contents(_path)
      revisions = change['revisions'].dup
      # fake the 0-th revision (before the change)
      # it includes all files modified in any of the patchset
      before = {}
      before['files'] = Hash[revisions
                        .values.map { |r| r['files'].keys }.flatten.uniq.map { |f| [f, {}] }]
      before['_number'] = 0
      revisions['0000'] = before

      files = revisions.map do |revid, revision|
        prefix = ".#{revision['_number']}_"
        changed_files = revisions[revid]['files'].keys + ['COMMIT_MSG']
        changed_files.map { |k| prefix + sanitize(k) }
      end

      [files, META_FILES].flatten
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
      when '/CURRENT_REVISION'
        current = change['current_revision']
        change['revisions'][current]['_number']
      when '/COMMIT_MSG'
        commit_file(change['current_revision'])
      when '/.0_COMMIT_MSG'
        ''
      when /\.(\d+)_COMMIT_MSG/
        commit_file(Regexp.last_match(1)) # TODO: handle commit like a normal file (with comments for instance)
      when /\.(\d+)_(.*)$/
        revision = Regexp.last_match(1).to_i
        filename = file_from_sanitized(Regexp.last_match(2))
        content = get_ab_file(Regexp.last_match(2), revision)
        FileWithComments.new(Regexp.last_match(2), content, comments(filename, revision), comments(filename, revision, draft: true))
      else
        "Nothing in there, see .xx_#{file} with xx the patchset version\n"
      end
    end

    def can_write?(path)
      case path
      when /\.sw(x|p)$/ # temporary vim files
        false
      when /^\/\.(\d+)_/
        true
      else
        false
      end
    end

    def write_to(path, content)
      case path
      when /^\/\.(\d+)_/
        revision = Regexp.last_match(1).to_i
        if content.empty?
          puts "Truncating #{path}, ignoring for now"
          return
        end
        write_comments(path, content, revision)
      else
        raise "Cannot write in #{path}"
      end
    end

    private

    include Sanitize

    def change
      @gerrit.change(@id, %w(ALL_REVISIONS ALL_FILES))
    end
    cache :change, 10

    # return the content of the file before/after the change
    def get_ab_file(sanitized_name, revision)
      # any version except the 0th will be reconstructed compared to base version.
      a_or_b = revision > 0 ? 'b' : 'a'
      reference = revision > 0 ? revision : 'current' # TODO: why happens if the file is not mentionned in the current revision ?
      file = file_from_sanitized(sanitized_name)
      puts "#{sanitized_name} => #{file}"
      diff = @gerrit.file_diff(@id, CGI.escape(file), reference)
      diff['content'].map do |content|
        res = [
          content['ab'],
          content[a_or_b]
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
    def commit_file(revision)
      c = @gerrit.commit(@id, revision)
      file = []
      file += c['parents'].map do |parent|
        "Parent:        #{parent['commit'][0..6]} (#{parent['subject']})"
      end
      file += %w(committer author).map do |t|
        [
          "#{t.capitalize}:     #{c[t]['name']} <#{c[t]['email']}>",
          "#{t.capitalize}Date: #{c[t]['date']}"
        ]
      end.flatten
      file << ''
      file << c['message']
      file.join("\n")
    end
    cache :commit_file, 10

    # Comments for the revision "0" are stored on revision 1 with the side "PARENT"
    # filter comments given their side: PARENT or REVISION
    def comments(file, revision, opts = {})
      method = opts[:draft] ? :draft_comments : :comments
      reference = revision > 0 ? revision : 1
      cs = @gerrit.send(method, @id, reference)[file] || []
      side = revision > 0 ? 'REVISION' : 'PARENT'
      cs.select { |c| (c['side'] || 'REVISION') == side }
    end
    cache :comments, 10

    def write_comments(path, content, revision)
      comments = parse_comments(path, content, revision)
      puts "Would submit #{comments.size} comment drafts"
      comments.each do |line, draft|
        puts '---'
        puts "Would draft comment at line #{line}"
        puts draft.join
        puts '---'
        draft.save(@gerrit)
      end
    end

    #  TODO refactor this method and add tests
    def parse_comments(path, content, revision)
      # cleaning BOM markers
      orig    = get_file(path)
      content = content.force_encoding('utf-8').gsub(/^\xEF\xBB\xBF/, '')
      f = file_from_sanitized(path.gsub(/^\/.(\d+)_/, ''))

      comments = Hash.new do |h, line|
        h[line] = DraftComment.new(@id, revision, f, line)
      end
      orig_enum = orig.each
      new_enum  = content.lines.each
      current_line = 1 # represent line number of content without comments
      inner_enum = nil # represent enum when inside a complex structure (comments)
      # at the end of this loop, drafted comments are in "comments" hash, indexed by their "current_line"
      loop do
        original_line = (begin
                           orig_enum.peek
                         rescue
                           nil
                         end)
        new_line      = (begin
                           new_enum.peek
                         rescue
                           nil
                         end) # this rescue does not seem to work
        if original_line.nil? && new_line.nil? # end
          break
        elsif new_line.nil? # very weird
          puts "Deleted line seems likely on line #{current_line}"
          puts "Original line: #{original_line.dump}"
          puts "Let's avoid infinite loop!"
          raise 'One or more lines have been removed from the original file!'
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
            inner_line      = (begin
                                 inner_enum.peek
                               rescue
                                 nil
                               end)
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
              raise 'Current comment has been modified ?'
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
