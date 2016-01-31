module GerritFS

  CachedResult = Struct.new(:result, :expire)

  module Cache
    # this module needs to be extended

    def cache(method_name, lifetime)
      alias_method "non_cached_{method_name}", method_name

      define_method(method_name) do
        @cache_module ||= {}
        if !@cache_module.has_key?(method_name) || !(@cache_module[method_name].expire > Time.now)
          res = send("non_cached_{method_name}")
          @cache_module[method_name] = CachedResult.new(
            res,
            (Time.now + lifetime)
          )
        end
        @cache_module[method_name].result
      end
    end
  end
end
