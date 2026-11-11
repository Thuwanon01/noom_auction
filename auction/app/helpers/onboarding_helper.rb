module OnboardingHelper
  # "1250000.0" => "1,250,000". Shows what the user typed if it was invalid.
  def annual_income_field_value(user)
    return user.annual_income_before_type_cast if user.errors.include?(:annual_income)
    return nil if user.annual_income.nil?

    income = user.annual_income
    number_with_delimiter(income == income.truncate ? income.to_i : income)
  end

  def grade_label(grade)
    "#{grade}: #{CreditScoring::GRADE_MEANINGS[grade]}"
  end

  # 0..1 position of a score on the 300-850 scale, for the gauge.
  def score_fraction(score, min: 300, max: 850)
    ((score.to_f - min) / (max - min)).clamp(0, 1)
  end

  def years_label(years)
    value = years == years.truncate ? years.to_i : years
    "#{value} ปี"
  end
end
