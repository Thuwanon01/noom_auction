module OnboardingHelper
  # "1250000.0" => "1,250,000". Shows what the user typed if it was invalid.
  def annual_income_field_value(user)
    return user.annual_income_before_type_cast if user.errors.include?(:annual_income)
    return nil if user.annual_income.nil?

    income = user.annual_income
    number_with_delimiter(income == income.truncate ? income.to_i : income)
  end
end
