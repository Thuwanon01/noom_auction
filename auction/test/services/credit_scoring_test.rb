require "test_helper"

class CreditScoringTest < ActiveSupport::TestCase
  def score(occupation: "private_employee", income: 480_000, experience: 4)
    CreditScoring.call(occupation: occupation, annual_income: income, years_experience: experience)
  end

  def points(part, **kw) = score(**kw).breakdown.fetch(part)

  test "score is 300 plus the three parts" do
    result = score
    assert_equal({ "occupation" => 120, "income" => 150, "experience" => 100 }, result.breakdown)
    assert_equal 670, result.score
    assert_equal "B", result.grade
    assert_equal "Good", result.grade_meaning
    assert_equal "v1-draft", result.model_version
  end

  test "every occupation" do
    { "government" => 150, "private_employee" => 120, "business_owner" => 100,
      "freelance" => 90, "other" => 60, "student_unemployed" => 40 }.each do |occupation, pts|
      assert_equal pts, points("occupation", occupation: occupation), occupation
    end
  end

  test "every income band and boundary" do
    {
      1 => 30, 119_999.99 => 30,
      120_000 => 90, 299_999 => 90,
      300_000 => 150, 599_999 => 150,
      600_000 => 210, 1_199_999 => 210,
      1_200_000 => 250, 100_000_000 => 250
    }.each { |income, pts| assert_equal pts, points("income", income: income), "income #{income}" }
  end

  test "every experience band and boundary" do
    {
      0 => 0, 0.1 => 20, 0.9 => 20,
      1 => 60, 2.9 => 60,
      3 => 100, 4.9 => 100,
      5 => 130, 9.9 => 130,
      10 => 150, 50 => 150
    }.each { |years, pts| assert_equal pts, points("experience", experience: years), "experience #{years}" }
  end

  test "minimum possible score is 300 + 40 + 30 + 0" do
    result = score(occupation: "student_unemployed", income: 1, experience: 0)
    assert_equal 370, result.score
    assert_equal "D", result.grade
  end

  test "maximum possible score is 850" do
    result = score(occupation: "government", income: 1_200_000, experience: 10)
    assert_equal 850, result.score
    assert_equal "A", result.grade
  end

  test "grade boundaries" do
    grades = CreditScoring::MODELS.fetch("v1-draft").fetch(:grades)
    { 850 => "A", 750 => "A", 749 => "B", 650 => "B", 649 => "C", 550 => "C", 549 => "D", 300 => "D" }.each do |s, g|
      assert_equal g, CreditScoring.send(:band, grades, s), "score #{s}"
    end
  end

  test "unknown occupation or missing input raises" do
    assert_raises(CreditScoring::Error) { score(occupation: "astronaut") }
    assert_raises(CreditScoring::Error) { score(income: nil) }
  end

  test "a new model version only needs a new MODELS entry" do
    v2 = CreditScoring::MODELS["v1-draft"].merge(base: 310)
    stub_const_models(CreditScoring::MODELS.merge("v2" => v2)) do
      result = CreditScoring.call(occupation: "government", annual_income: 1, years_experience: 0, version: "v2")
      assert_equal 490, result.score
      assert_equal "v2", result.model_version
    end
  end

  test "score_user! stores an audit row and copies the result to the user" do
    user = users(:fresh)
    user.update!(occupation: "freelance", annual_income: 700_000, years_experience: 2)

    assert_difference -> { user.credit_scores.count }, 1 do
      CreditScoring.score_user!(user)
    end

    audit = user.credit_scores.last
    assert_equal 300 + 90 + 210 + 60, audit.score
    assert_equal "B", audit.grade
    assert_equal "v1-draft", audit.model_version
    assert_equal({ "occupation" => "freelance", "annual_income" => "700000.0", "years_experience" => "2.0" }, audit.inputs)
    assert_equal({ "occupation" => 90, "income" => 210, "experience" => 60 }, audit.breakdown)

    user.reload
    assert_equal [ 660, "B", "v1-draft" ], [ user.credit_score, user.credit_grade, user.score_model_version ]
  end

  private

  def stub_const_models(models)
    original = CreditScoring::MODELS
    CreditScoring.send(:remove_const, :MODELS)
    CreditScoring.const_set(:MODELS, models)
    yield
  ensure
    CreditScoring.send(:remove_const, :MODELS)
    CreditScoring.const_set(:MODELS, original)
  end
end
