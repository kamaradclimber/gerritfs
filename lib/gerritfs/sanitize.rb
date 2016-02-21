module GerritFS
  module Sanitize
    def sanitize(name)
      name.gsub(/[^\w\.]/, '_')
    end
  end
end
