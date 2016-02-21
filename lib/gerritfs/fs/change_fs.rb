require 'cgi'

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
      file = path[1..-1]
      case path
      when "/COMMIT_MSG"
        commit_file
      when "/.a_COMMIT_MSG"
        ""
      when "/.b_COMMIT_MSG"
        commit_file
      when /\.(a|b)_(.*)$/
        get_ab_file_with_comments($2, $1)
      else
        "Nothing in there, see .a_#{file} and .b_#{file}\n"
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
      diff = @gerrit.file_diff(@id, CGI.escape(file))
      diff['content'].map do |content|
        res = [content["ab"]]
        res << content[a_or_b] if content[a_or_b]
        res
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

    def get_ab_file_with_comments(sanitized_name, a_or_b)
      file_content = get_ab_file(sanitized_name, a_or_b).lines
      comment_overlay = [nil].cycle.take(file_content.size)
      if a_or_b == 'b'
        file_name    = file_from_sanitized(sanitized_name)
        comments(file_name).
          group_by { |c| c['line'] }.
          each do |line, cs|
            comment_overlay[line -1] = cs.
              sort_by { |c| c['updated'] }.
              map do |c|
                format_comment(c)
              end.join("\n")
          end
      end
      file_content.zip(comment_overlay).map do |l,c|
        if c then l + c + "\n" else l end
      end.join
    end

    def format_comment(c)
      <<-EOH.gsub(/^\s+/,'')
      Comment by #{c['author']['name']}: #{c['message']}
      EOH
    end

  end
end
