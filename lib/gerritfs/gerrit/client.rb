require 'httpclient'
require 'json'
require 'mash'

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

      def changes(query)
        response = @client.get(base_url + '/a/changes/' + '?' + query)
        if response.code == 200
        JSON.parse(strip(response.body)) 
        else
          raise "Invalid response code #{response.code}", response
        end
      end

      def clone_url_for(project)
        @ssh_url + project + '.git'
      end

      def projects
        response = @client.get(base_url + '/a/projects/') 
        if response.code == 200
        JSON.parse(strip(response.body)) 
        else
          raise "Invalid response code #{response.code}", response
        end
      end
    end
  end
end
