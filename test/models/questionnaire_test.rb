require "test_helper"

class QuestionnaireTest < ActiveSupport::TestCase
  test "template questionnaires clear template source automatically" do
    questionnaire = questionnaires(:survey_template)
    questionnaire.template_source_id = questionnaires(:checklist).id

    questionnaire.valid?

    assert_nil questionnaire.template_source_id
  end

  test "non template questionnaires can reference template" do
    questionnaire = questionnaires(:checklist)
    questionnaire.template_source = questionnaires(:survey_template)

    assert questionnaire.valid?
  end
end
