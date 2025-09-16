require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @questionnaire = questionnaires(:checklist)
  end

  test "creates question" do
    assert_difference("Question.count") do
      post questionnaire_questions_url(@questionnaire), params: { question: { prompt: "Test prompt", response_type: "text" } }
    end

    assert_redirected_to questionnaire_url(@questionnaire)
  end
end
