module CrowdIn
  # Helper methods when interacting with files in CrowdIn.
  module FileMethods
    # Iterate over file paths safely by catching and collecting failures.
    # Returns failures as hash of { file: error_message }
    def safe_file_iteration(files)
      failed_files = {}
      files.each do |f|
        begin
          yield f
        rescue CrowdIn::Client::Errors::Error => e
          failed_files[f] = e.to_s
        end
      end
      failed_files.empty? ? nil : FilesError.new(failed_files)
    end

    def file_name(object_type, object_id)
      sanitized_object_type = object_type.gsub(/::/, '_')
      base_name = [sanitized_object_type, object_id].join('-')
      base_name + ".json"
    end

    class FilesError < StandardError
      attr_accessor :errors_by_file

      def initialize(errors_by_file)
        @errors_by_file = errors_by_file
      end

      def to_s
        "Failed files: #{@errors_by_file}"
      end
    end
  end
end
