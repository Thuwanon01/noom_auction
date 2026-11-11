# Draft credit scoring model from requirement/onboardingFlow.md (Step 3).
#
#   score = base + occupation_pts + income_pts + experience_pts   (300..850)
#
#   CreditScoring.call(occupation: "private_employee", annual_income: 480_000, years_experience: 4)
#   # => Result(score: 670, grade: "B", breakdown: {...}, model_version: "v1-draft", inputs: {...})
#
#   CreditScoring.score_user!(user)  # scores, writes a CreditScore audit row, copies score to the user
#
# To change the model, add a new entry to MODELS and point CURRENT_VERSION at
# it. Old CreditScore rows keep the version they were scored with.
#
# Band boundaries: every range below includes its lower bound and excludes its
# upper bound, so a value exactly on a boundary falls into the HIGHER band:
#   income 120,000 -> 90 pts, 300,000 -> 150, 600,000 -> 210, 1,200,000 -> 250
#   experience 1 yr -> 60 pts, 3 -> 100, 5 -> 130, 10 -> 150
# Experience of exactly 0 scores 0; anything above 0 and below 1 year scores 20.
# The first matching band wins.
class CreditScoring
  class Error < StandardError; end

  MODELS = {
    "v1-draft" => {
      base: 300,
      occupation: {
        "government"         => 150,
        "private_employee"   => 120,
        "business_owner"     => 100,
        "freelance"          => 90,
        "other"              => 60,
        "student_unemployed" => 40
      },
      income: [
        [ ...120_000,              30 ],
        [ 120_000...300_000,       90 ],
        [ 300_000...600_000,      150 ],
        [ 600_000...1_200_000,    210 ],
        [ 1_200_000..,            250 ]
      ],
      experience: [
        [ 0..0,      0 ],
        [ 0...1,    20 ],
        [ 1...3,    60 ],
        [ 3...5,   100 ],
        [ 5...10,  130 ],
        [ 10..,    150 ]
      ],
      grades: [
        [ 750..,     "A" ],
        [ 650...750, "B" ],
        [ 550...650, "C" ],
        [ ...550,    "D" ]
      ]
    }
  }.freeze

  CURRENT_VERSION = "v1-draft"

  GRADE_MEANINGS = {
    "A" => "Excellent",
    "B" => "Good",
    "C" => "Fair",
    "D" => "Needs improvement"
  }.freeze

  Result = Data.define(:score, :grade, :breakdown, :model_version, :inputs) do
    def grade_meaning = GRADE_MEANINGS[grade]
  end

  def self.call(occupation:, annual_income:, years_experience:, version: CURRENT_VERSION)
    model = MODELS.fetch(version) { raise Error, "Unknown scoring model #{version}" }
    raise Error, "Missing scoring input" if [ occupation, annual_income, years_experience ].any?(&:nil?)

    income = annual_income.to_d
    experience = years_experience.to_d
    breakdown = {
      "occupation" => model[:occupation].fetch(occupation.to_s) { raise Error, "Unknown occupation #{occupation}" },
      "income" => band(model[:income], income),
      "experience" => band(model[:experience], experience)
    }
    score = model[:base] + breakdown.values.sum

    Result.new(
      score: score,
      grade: band(model[:grades], score),
      breakdown: breakdown,
      model_version: version,
      inputs: { "occupation" => occupation.to_s, "annual_income" => income.to_s("F"),
                "years_experience" => experience.to_s("F") }
    )
  end

  # Scores the user's saved Step 2 data, keeps an audit row, and copies the
  # latest score and grade onto the user. Returns the Result.
  def self.score_user!(user, version: CURRENT_VERSION)
    result = call(occupation: user.occupation, annual_income: user.annual_income,
                  years_experience: user.years_experience, version: version)

    user.transaction do
      user.credit_scores.create!(score: result.score, grade: result.grade, breakdown: result.breakdown,
                                 inputs: result.inputs, model_version: result.model_version)
      user.update!(credit_score: result.score, credit_grade: result.grade, score_model_version: result.model_version)
    end
    result
  end

  def self.band(bands, value)
    bands.each { |range, points| return points if range.cover?(value) }
    raise Error, "No band for #{value}"
  end
  private_class_method :band
end
