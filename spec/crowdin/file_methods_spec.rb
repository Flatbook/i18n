require 'spec_helper'
require 'crowdin/client/error'

RSpec.describe CrowdIn::FileMethods do
  let(:test_class) { Class.new { include CrowdIn::FileMethods } }

  context "#safe_file_iteration" do
    let(:files) { [1, 2] }

    it "yields for all files when there are no failures" do
      successes = []
      failures = test_class.new.safe_file_iteration(files) { |f| successes.append(f+1) }
      expect(successes).to eq [2, 3]
      expect(failures).to be_nil
    end

    it "returns failures for any files raises a clilent error" do
      error_msg = "some error"
      successes = []
      failures = test_class.new.safe_file_iteration(files) do |f|
        f == 2 ? successes.append(f+1) : raise(CrowdIn::Client::Errors::Error.new(1, error_msg))
      end
      expect(successes).to eq [3]
      expect(failures).to eq(CrowdIn::FileMethods::FilesError.new({ 1 => "1: #{error_msg}" }))
    end
  end
end
