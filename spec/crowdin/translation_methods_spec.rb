require 'spec_helper'

RSpec.describe CrowdIn::TranslationMethods do
  let(:test_class) { Class.new { include CrowdIn::TranslationMethods } }
  subject { test_class.new }

  context "#split_into_sentences" do
    it "returns hash with text split on sentence endings" do
      input = {
          "key1" => "sentence one. sentence two.",
          "key2" => "sentence one? sentence two.",
          "key3" => "sentence one! sentence two.",
          "key4" => "sentence one\n sentence two.",
      }
      output = {
          "key1" => ["sentence one.", "sentence two."],
          "key2" => ["sentence one?", "sentence two."],
          "key3" => ["sentence one!", "sentence two."],
          "key4" => ["sentence one\n sentence two."],
      }
      expect(subject.split_into_sentences(input)).to eq output
    end
  end

  context "#join_sentences" do
    it "returns single sentences for translations" do
      input = { "key1" => ["sentence one.", "sentence two."], "key2" => "sentence three" }
      output = { "key1" => "sentence one. sentence two.", "key2" => "sentence three" }
      expect(subject.join_sentences(input)).to eq output
    end
  end
end
