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
        get_ab_file($2, $1)
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

    def get_ab_file(sanitized_name, a_or_b)
      current_revision = change['current_revision']
      file = change['revisions'][current_revision]['files'].keys.find { |k| sanitize(k) == sanitized_name }
      diff = @gerrit.file_diff(@id, CGI.escape(file))
      diff['content'].map do |content|
        res = [content["ab"]]
        res << content[a_or_b] if content[a_or_b]
        res
      end.flatten.join("\n")
    end

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
  end
end
