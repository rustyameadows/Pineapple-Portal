require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  test "syncs event with questionnaire" do
    questionnaire = questionnaires(:checklist)
    question = questionnaire.questions.build(prompt: "Test", response_type: "text")

    assert question.valid?
    assert_equal questionnaire.event, question.event
  end

  test "template question cannot store answers" do
    question = questions(:second)
    question.answer_value = "Yes"

    assert_not question.valid?
    assert_includes question.errors[:base], "Template questions cannot store answers"
  end
end
