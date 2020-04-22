module ActiveSupport
  module Inflector
    def titleize(word, keep_id_suffix: false, name: false)
      name ?
        humanize(word).strip.gsub(/\b([a-z])/) { $1.capitalize }.
          sub(/^Mc([a-z]{2,})/) { "Mc#{$1.capitalize}" }.
          gsub(/(['’`])([A-Z]{1})(\s|$)/) {|m| m.downcase }.
          sub(/^[A-Z]j$/) {|m| m.upcase } :
        humanize(underscore(word).strip, keep_id_suffix: keep_id_suffix).gsub(/\b(?<!\w['’`])[a-z]/) do |match|
          match.capitalize
        end
    end
  end
end
