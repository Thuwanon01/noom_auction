# Hide most of a national ID or phone number before showing it.
module MaskingHelper
  # "1234567890121" => "1-2345-XXXXX-XX-1"
  def mask_national_id(id)
    d = id.to_s
    return "" unless d.match?(/\A\d{13}\z/)

    "#{d[0]}-#{d[1, 4]}-XXXXX-XX-#{d[12]}"
  end

  # "0812341234" => "08X-XXX-1234"
  def mask_phone(phone)
    d = phone.to_s
    return "" unless d.match?(/\A\d{10}\z/)

    "#{d[0, 2]}X-XXX-#{d[6, 4]}"
  end
end
