require 'rubygems/text'
# $stdout.reopen("out.txt", "w")
# $stderr.reopen("err.txt", "w")

class String
  def self.decrypt_token(str)
    JSON.parse(decrypt_gpg_base64(str.strip))
  rescue
    ""
  end

  def self.levenshtein_distance(*args)
    @@ld ||= Class.new.extend(Gem::Text).method(:levenshtein_distance)
    @@ld.call(*args)
  end

  def rrd_safe
    dup.rrd_safe!
  end

  def rrd_safe!
    tr!(
      "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšȘșſŢţŤťŦŧȚțÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž’",
      "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSsSssTtTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz'"
    )
    self
  end

  def abbr_format
    dup.abbr_format!
  end

  def abbr_format!
    upcase!
    gsub!(/[^A-Z]/, '')
    slice!(3..-1)
    self
  end

  def decrypt_token
    String.decrypt_certificate(self)
  end

  def decrypt_token!
    self.replace decrypt_certificate
  end

  def dus_id_format
    dup.dus_id_format!
  end

  def dus_id_format!
    upcase!
    gsub!(/[^A-Z]/, '')
    slice!(6..-1)
    self
  end

  def phone_format
    dup.phone_format!
  end

  def phone_format!
    return '' unless present?

    if self =~ /^\+[^1]/
      gsub!(/[^+0-9]/, '')
    else
      gsub!(/^\+?1|[^0-9]/, '')
      slice!(10..-1)
    end

    return self if length < 10

    case self
    when /^\+6/
      if self =~ /^\+61/
        sub!(
          /(\+6\d)(.*)/,
          "\\1 #{
            "0#{slice(3..-1)}".sub(/^0+/, '0').phone_format.sub(/^0/, '')
          }"
        )
      end
      strip!
    when /^04/
      self
      sub!(/(\d{4})?(\d{3})?/, '\1 \2 ')
      sub!(/\s+/, ' ')
      strip!
    when /^0/
      sub!(/(\d{2})?(\d{4})?/, '\1 \2 ')
      sub!(/\s+/, ' ')
      strip!
    else
      return self if length < 4
      sub!(/(\d{3})?(\d{3})?/, '\1-\2-')
      sub!('--', '-')
    end

    self
  end

  def pid_format
    dup.pid_format!
  end

  def pid_format!
    return '' unless present?
    upcase!
    gsub!(/[^A-Z0-9]/, '')
    replace(rjust(12, '0'))
    self
  end

  def titleize(name: true, keep_id_suffix: false)
    ActiveSupport::Inflector.titleize(self, name: name, keep_id_suffix: name || keep_id_suffix)
  end

  def distance(str)
    self.class.levenshtein_distance(self, str)
  end

  def hyphenated
    underscore.gsub(/\s+|_/, '-')
  end

  unless defined?(og_to_i)
    alias :og_to_d :to_d
    alias :og_to_i :to_i

    def to_i
      begin
        is_time_interval? ? to_d.to_i : og_to_i
      rescue
        og_to_i
      end
    end

    def to_d
      begin
        if is_time_interval?
          self.split(':').
            map { |a| a.to_d }.
            inject(0) { |a, b| a * BigDecimal(60) + b}
        else
          og_to_d
        end
      rescue
        og_to_d
      end
    end
  end

  def from_b64
    dup.from_b64!
  end

  def from_b64!
    replace(Base64.strict_decode64(self))
  end

  def to_b64
    dup.to_b64!
  end

  def to_b64!
    replace(Base64.strict_encode64(self))
  end

  def us_date_to_iso
    dup.us_date_to_iso!
  end

  def us_date_to_iso!
    m, d, y = self.split('/')
    replace("20#{y.rjust(4, '0')[-2..-1]}-#{m.rjust(2, '0')}-#{d.rjust(2, '0')}")
  end

  def us_date_to_iso_if_needed
    dup.us_date_to_iso_if_needed!
  end

  def us_date_to_iso_if_needed!
    if self =~ /\d+\/\d+\/\d+/
      us_date_to_iso!
    else
      self
    end
  end

  private
    def is_time_interval?
      !!(self =~ /\d+:\d+:\d+/)
    end

end
