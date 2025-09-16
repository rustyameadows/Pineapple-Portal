require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @questionnaire = questionnaires(:checklist)
  end

  test "creates question" do
    assert_difference("Question.count") do
      post event_questionnaire_questions_url(@questionnaire.event, @questionnaire), params: { question: { prompt: "Test prompt", response_type: "text" } }
    end

    assert_redirected_to event_questionnaire_url(@questionnaire.event, @questionnaire)
  end

  test "saves answer and creates attachment" do
    question = questions(:first)
    event = question.event
    logical_id = SecureRandom.uuid

    assert_difference(["Document.count", "Attachment.count"], 1) do
      patch answer_event_questionnaire_question_url(event, question.questionnaire, question), params: {
        question: {
          answer_value: "Confirmed",
          file_storage_uri: "documents/#{event.id}/upload/v1/proof.pdf",
          file_checksum: "checksum",
          file_size_bytes: "512",
          file_content_type: "application/pdf",
          file_title: "Proof.pdf",
          file_logical_id: logical_id
        }
      }
    end

    assert_redirected_to event_questionnaire_url(event, question.questionnaire)
    assert_equal "Confirmed", question.reload.answer_value
    assert_equal logical_id, Attachment.last.document.logical_id
  end

  test "reorders questions" do
    question_ids = @questionnaire.questions.order(:position).pluck(:id)
    patch reorder_event_questionnaire_questions_url(@questionnaire.event, @questionnaire), params: { order: question_ids.reverse }

    assert_response :success
    assert_equal question_ids.reverse, @questionnaire.questions.order(:position).pluck(:id)
  end
end
