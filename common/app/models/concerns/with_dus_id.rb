module WithDusId
  extend ActiveSupport::Concern

  def admin_url
    url true
  end

  def dus_id
    formatted_dus_id self[:dus_id]
  end

  def dus_id=(val)
    val = val.to_s.dus_id_format.presence
    return super if !val

    if (val.size == 6) && (!(existing = self.class.get(val)) || (existing.id === self.id))
      super(val)
    else
      false
    end
  end

  def dus_id_hash
    self.class.get_sha256_digest(self.dus_id&.dus_id_format)
  end

  def formatted_dus_id(d_id)
    d_id.to_s.scan(/.{1,3}/).join('-').presence
  end

  def url(fetching_admin_url = false, category = nil, amount = nil)
    domain =
      Rails.env.development? ?
        local_host :
        "https://#{fetching_admin_url ? 'admin.' : 'www.'}downundersports.com"

    base = fetching_admin_url ? '/admin/users' : ''
    category = category.presence && "/#{category}"
    amount = amount.presence && "?amount=#{amount}"

    "#{domain}#{base}#{category}/#{dus_id}#{amount}"
  end

  def payment_url(amount = nil)
    money_url('payment', amount)
  end

  def deposit_url(amount = nil)
    money_url('deposit', amount)
  end

  def money_url(category, amount = nil)
    url(false, category, amount)
  end

  def hash_url(page)
    "#{local_host}/#{page}/#{dus_id_hash}"
  end

  def checklist_url
    hash_url 'departure-checklist'
  end

  def qr_code_link(url)
    "https://www.downundersports.com/api/qr_codes/#{encode_uri_component(encode64(url))}"
  end

  def encode_uri_component(string)
    URI.escape(string.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def encode64(str)
    require "base64"
    Base64.strict_encode64 str
  end
end
