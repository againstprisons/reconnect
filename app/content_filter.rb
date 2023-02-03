require 'sanitize'

class ReConnect::ContentFilter
  EMOJI_REGEXP = /<a?:.+?:\d{18}>|\p{Extended_Pictographic}/u

  attr_accessor :enabled
  attr_accessor :words

  def initialize
    @enabled = true
    @words = []
  end

  def do_filter(content)
    return [] unless @enabled
    matched = []

    # Run sanitize on content to strip out all HTML
    content = Sanitize.fragment(content)

    # Split into words, do basic word matching on each word
    content.split(/\s+/).map{|x| x.split("-")}.flatten.compact.each do |p_full|
      p_full.strip.downcase.split(/\W+/).map(&:strip).each do |partial|
        @words.each do |to_match|
          if partial == to_match
            matched << to_match
          end
        end
      end
    end

    # Check for emoji
    content.scan(EMOJI_REGEXP).each do |em|
      matched << em
    end

    matched
  end
end
