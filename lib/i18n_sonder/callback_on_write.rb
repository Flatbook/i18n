module I18nSonder
  class CallbackOnWrite
    class << self
      def register(&block)
        @callback = block
      end

      def trigger
        @callback
      end
    end
  end
end
