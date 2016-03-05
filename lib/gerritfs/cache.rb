module GerritFS

  CachedResult = Struct.new(:result, :expire)

  module Cache
    # this module needs to be extended

    def cache(method_name, lifetime)
      alias_method "non_cached_#{method_name}", method_name

      define_method(method_name) do |*args|
        @cache_module ||= {}
        key = ([method_name] + args.map(&:hash)).join('_')
        if !@cache_module.has_key?(key) || !(@cache_module[key].expire > Time.now)
          res = send("non_cached_#{method_name}", *args)
          @cache_module[key] = CachedResult.new(
            res,
            (Time.now + lifetime)
          )
        else
          #puts "Using cached version of #{method_name}(#{args})"
        end
        @cache_module[key].result
      end
    end
  end
end
