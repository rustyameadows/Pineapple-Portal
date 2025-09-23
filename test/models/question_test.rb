require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  test "syncs event with questionnaire" do
    questionnaire = questionnaires(:checklist)
    section = questionnaire.sections.first
    assert_not_nil section, "questionnaire fixture should include a section"

    question = questionnaire.questions.build(
      prompt: "Test",
      response_type: "text",
      questionnaire_section: section,
      position: section.questions.maximum(:position).to_i + 1
    )

    assert question.valid?
    assert_equal questionnaire.event, question.event
  end
end
