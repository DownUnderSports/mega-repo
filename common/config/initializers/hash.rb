class Hash
  def null_to_str
    dup.map {|k, v| [k, v || '']}.to_h
  end

  def nullify_blank
    dup.map {|k, v| [k, v.presence]}.to_h
  end

  def present_only
    dup.present_only!
  end

  def present_only!
    select! {|k, v| v.present? }
    self
  end
end
