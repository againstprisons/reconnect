require 'sanitize'

class ReConnect::ContentFilter
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
    content.split(" ").map{|x| x.split("-")}.flatten.each do |partial|
      partial = partial.strip.downcase
      @words.each do |to_match|
        if partial == to_match
          matched << to_match
        end
      end
    end

    matched
  end
end
