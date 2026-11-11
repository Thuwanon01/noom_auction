# Audit record of one credit scoring run. See CreditScoring.
class CreditScore < ApplicationRecord
  belongs_to :user

  validates :score, :grade, :model_version, presence: true
end
