module I18nSonder
  class ExecuteCallbackOnWrite
    class << self
      def write_event_callback(&block)
        @callback = block
      end

      def callback
        @callback
      end
    end
  end
end
