class Encoder
  def initialize(str)
    @str = str
  end

  def to_utf8
    return @str if is_utf8?
    encoding = find_encoding
    @str.force_encoding(encoding).encode('utf-8', invalid: :replace, undef: :replace)
  end

  def find_encoding
    puts 'utf-8' if is_utf8?
    puts 'iso-8859-1' if is_iso8859?
    return 'iso-8859-1' if is_iso8859?
    puts 'Windows-1252' if is_windows?
    return 'Windows-1252' if is_windows?
    raise ArgumentError.new "Invalid Encoding"
  end

  def is_utf8?
    is_encoding?(Encoding::UTF_8)
  end

  def is_iso8859?
    is_encoding?(Encoding::ISO_8859_1)
  end

  def is_windows?(str)
    is_encoding?(Encoding::Windows_1252)
  end

  def is_encoding?(encoding_check)
    case @str.encoding
    when encoding_check
      @str.valid_encoding?
    when Encoding::ASCII_8BIT, Encoding::US_ASCII
      @str.dup.force_encoding(encoding_check).valid_encoding?
    else
      false
    end
  end
end
