require 'httpclient'
require 'json'
require 'mash'
require 'base64'

module GerritFS
  module Gerrit
    class Client

      MAGIC = /^\)\]}'\n/
      def strip(body)
        body.gsub(MAGIC, '')
      end

      def initialize(opts)
        unless opts.base_url && opts.username && opts.password
          raise "Missing option!"
        end
        base_url opts.base_url
        @ssh_url = 'ssh://' + opts.username + '@' + base_url.gsub(/\/$/,'').gsub(/http(s)?:\/\//,'')+ ':29418/'
        @client = HTTPClient.new
        @client.set_auth(base_url, opts.username, opts.password)
      end


      def base_url(url=nil)
        @base_url = url if url
        @base_url
      end

      def get(path)
        response = @client.get(base_url + path)
        if response.code == 200
          case response.header['Content-Type'].first
          when /json/
            JSON.parse(strip(response.body))
          when /text\/plain/
            Base64.decode64(response.body)
          else
            raise "Unknown content-type #{response.header['Content-Type']}"
          end
        else
          puts (base_url + path)
          puts response.code
          puts response.body
          raise "Invalid response code #{response.code}", response
        end
      end

      def changes(query)
        get('/a/changes/' + '?' + query)
      end

      def change(id, fields=[])
        suffix = "?" + fields.map {|f| "o=#{f}" }.join('&') unless fields.empty?
        get("/a/changes/#{id}#{suffix}")
      end

      def change_patch(id, revision = "current")
        get("/a/changes/#{id}/revisions/#{revision}/patch")
      end

      def file_diff(id, file, revision = "current")
        get("/a/changes/#{id}/revisions/#{revision}/files/#{file}/diff")
      end

      def commit(id, revision = "current")
        get("/a/changes/#{id}/revisions/#{revision}/commit")
      end

      def clone_url_for(project)
        @ssh_url + project + '.git'
      end

      def projects
        get('/a/projects/')
      end
    end
  end
end
