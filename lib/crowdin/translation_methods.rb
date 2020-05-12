module CrowdIn
  # Helper methods when interacting with translations phrases in CrowdIn.
  module TranslationMethods
    # A crude approach to splitting sentences that is sufficient to achieve the de-duplication
    # necessary for optimizing cost with CrowdIn.
    #
    # Input is a Hash of { attribute: value }, where value needs to be split.
    def split_into_sentences(attribute_value_pairs)
      attribute_value_pairs.map do |attribute, text|
        # Split by ".", "?", "!" characters, and remove trailing whitespaces
        s = text&.split(/(?<=\. |\? |\! )/)&.map { |w| w.gsub(/ $/, '') }
        [attribute, s]
      end.to_h
    end

    # Reverse of +split_into_sentences+
    def join_sentences(translations)
      translations.map do |attribute, translations|
        if translations.is_a? Array
          full_translation = translations.inject { |full_phrase, phrase| "#{full_phrase} #{phrase}" }
        else
          full_translation = translations
        end
        [attribute, full_translation]
      end.to_h
    end
  end
end

