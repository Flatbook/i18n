require "mobility"
require "mobility/plugins/active_record/query"

# This plugin allows querying fields that are marked as translatable for the Mobility gem.
# When using +where+, +select+, +pluck+, +order+, or +group+ to query such fields,
# the query should be constructed with the +i18n+ scope to get the localized result,
# e.g. +Neighborhood.i18n.select(:description)+.
#
# This custom plugin derives most of its functionality from the default Query plugin
# that comes with Mobility. See this implementation at +Mobility::Plugins::ActiveRecord::Query+.
#
# NOTE: Only use this in conjunction with the DefaultLocaleOptimizedKeyValue backend.
#
# We optimize queries made in the default locale, as configured by the
# i18n.default_locale parameter, so that they bypass Mobility's Query logic and
# query the Model's table itself.
module Mobility
  module Plugins
    module LocaleOptimizedQuery
      class << self
        def apply(attributes, option)
          return unless option

          # Call Mobility's default Query module, which sets up all the behavior
          # to query the translation tables.
          ActiveRecord::Query.apply(attributes)

          attributes.model_class.class_eval do
            extend LocaleOptimizedQueryMethod

            # alias the +i18n+ scope, defined by +Mobility.query_method+, to our custom function
            singleton_class.send :alias_method, Mobility.query_method, :locale_optimized_scope
          end

          # Include the instance methods from the default Query plugin, as well as from this plugin.
          # Particularly, we need the overriden +read+ methods in each plugin.
          attributes.backend_class.include ActiveRecord::Query
          attributes.backend_class.include self
        end

        # Counter-part to +Mobility::Plugins::ActiveRecord::Query::attribute_alias()+.
        # Returns empty string if no attribute can be found.
        def extract_attribute_from_alias(attribute)
          attrs = attribute.scan(/__mobility_(.*)_[a-zA-z\-]+__/)
          attrs.present? ? attrs.last.first : ""
        end
      end

      # Overriding Query plugin' +read+ for the edge case when the locale is the default locale,
      # and the attribute keys on the model are not an exact match.
      #
      # To better undestand why this can happen, please see
      # +Mobility::Plugins::ActiveRecord::Query::read()+. On a +select+ query, the translatable
      # column is loaded with a locale specific key, e.g. for a 'description' field, it would
      # store the value under the +__mobility_description_fr__+ key. When we try to fallback to
      # the default locale, we look for the +description+ key and fail. This method instead
      # reloads the entire model from the library in the default locale and return the
      # value of the necessary +attribute+.
      def read(locale, **)
        if locale == I18n.default_locale
          # +attribute+ is an instance variable on the backend representing the attribute to receive
          # +model.attributes+ will have the attributes set on the model,
          # i.e. __mobility__{attribute}__{locale}_ for certain Queries.
          includes_attribute = model.attributes.keys.any? do |k|
            LocaleOptimizedQuery.extract_attribute_from_alias(k) == attribute
          end

          # :id must be present in order to reload the object
          includes_id = model.attributes.include?(:id) || model.attributes.include?(:id.to_s)
          if includes_attribute && includes_id
            model.reload.read_attribute(attribute)
          else
            super
          end
        else
          super
        end
      end

      # Kept in a module for separation, and to mirror the logic in
      # +Mobility::Plugins::ActiveRecord::Query::QueryMethod+
      module LocaleOptimizedQueryMethod
        # if the locale is the default locale, then return +all+ scope
        # so that the scope is a simple passthrough.
        def locale_optimized_scope(locale: Mobility.locale, &block)
          if locale == I18n.default_locale
            all
          else
            # +__mobility_query_scope__+ is defined in +Mobility::Plugins::ActiveRecord::Query::QueryMethod+
            # and already applied to the Model class when we set up the default Query plugin.
            __mobility_query_scope__(locale: locale, &block)
          end
        end
      end
    end
  end
end
