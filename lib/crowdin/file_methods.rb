require 'active_support/core_ext/string'

module CrowdIn
  # Helper methods when interacting with files in CrowdIn.
  # This could be files themselves, file_paths, or the file tree.
  module FileMethods
    ROOT_DIR = 'models'

    # Traverse the directory of files starting at root folder,
    # and return only files with all translations approved.
    #
    # The return data structure is an array of full file paths,
    # e.g. ['root/to/file1', 'root/file2', ... ]
    def filter_approved_files(file_tree)
      root_dir = file_tree.select { |f| f['name'] == ROOT_DIR }
      filter_file_tree(root_dir, '')
    end

    def filter_file_tree(files_tree, prefix)
      approved_files = []

      files_tree.each do |file_hash|
        node_type = file_hash['node_type']
        name = file_hash['name']
        full_name = [prefix, name].join('/')
        children = file_hash['files']
        strings_count = file_hash['phrases'].to_i
        approved_count = file_hash['approved'].to_i

        if node_type == 'directory' && children.present?
          approved_files += filter_file_tree(children, full_name)
        elsif strings_count > 0 && strings_count == approved_count
          # If the count of strings is 0, then the entire file is duplicates,
          # and we skip duplicate files. Otherwise, we check to see if all
          # strings are approved.
          approved_files.append(full_name)
        end
      end

      approved_files
    end

    def extract_updated_from_file_path(file_path)
      path_to = File.dirname(file_path)
      file_name = File.basename(file_path, ".*")
      type, id, updated = file_name.split('-')

      [
          "#{path_to}/#{[type, id].join('-')}#{File.extname(file_path)}",
          updated
      ]
    end

    def add_updated_to_file_path(file_path, updated)
      path_to = File.dirname(file_path)
      file_name = File.basename(file_path, ".*")
      type, id = file_name.split('-')

      "#{path_to}/#{[type, id, updated].join('-')}#{File.extname(file_path)}"
    end

    def object_name_and_id(file_path)
      object_name = File.dirname(file_path).split('/').drop(1).map(&:camelize).join('::')
      file_name = File.basename(file_path, ".*")
      _, id = file_name.split('-')

      [object_name, id]
    end

    # Iterate over file paths safely by catching and collecting failures.
    # Returns failures as hash of { file: error_message }
    def safe_file_iteration(files)
      failed_files = {}
      files.each do |f|
        begin
          yield f
        rescue CrowdIn::Client::Errors::Error => e
          failed_files[file] = e.error_message
        end
      end
      failed_files
    end
  end
end
