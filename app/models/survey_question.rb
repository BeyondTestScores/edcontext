class SurveyQuestion < ApplicationRecord

  belongs_to :survey
  belongs_to :question

  after_commit :create_survey_monkey, on: :create
  after_commit :destroy_survey_monkey, on: :destroy

  def create_survey_monkey
    survey.create_survey_monkey_question(self)
  end

  def destroy_survey_monkey
    survey.remove_survey_monkey_question(self)
  end

end
