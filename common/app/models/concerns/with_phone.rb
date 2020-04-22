module WithPhone
  extend ActiveSupport::Concern

  def phone=(val)
    val = val.to_s.phone_format.presence
    return super(nil) if !val

    if (val.size == 12)
      super(val)
    else
      false
    end
  end
end
