# Amounts are kept in US cents everywhere (BomItem, Submission, GrantPayout).
module Money
  def self.format(cents) = "#{"-" if cents.to_i.negative?}$#{ActiveSupport::NumberHelper.number_to_delimited(format_number(cents.to_i.abs))}"

  def self.format_number(cents) = cents % 100 == 0 ? (cents / 100).to_s : "%.2f" % (cents / 100.0)
end
