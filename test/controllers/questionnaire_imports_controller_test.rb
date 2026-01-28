require "test_helper"

class QuestionnaireImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @source_event = events(:one)
    @event = events(:two)
    @source_questionnaire = questionnaires(:checklist)
  end

  test "shows import page" do
    get event_questionnaire_import_url(@event)
    assert_response :success
    assert_select "h1", text: "Import a questionnaire"
  end

  test "imports questionnaire as new" do
    questions(:first).update!(answer_value: "Yes", answer_raw: { "value" => "Yes" }, answered_at: Time.current)

    assert_difference("Questionnaire.count", 1) do
      post event_questionnaire_import_url(@event), params: {
        source_event_id: @source_event.id,
        source_questionnaire_id: @source_questionnaire.id,
        import_mode: "new",
        new_title: "Copied Checklist"
      }
    end

    imported = Questionnaire.last
    assert_equal @event.id, imported.event_id
    assert_equal "Copied Checklist", imported.title
    assert_equal @source_questionnaire.sections.count, imported.sections.count
    assert_equal @source_questionnaire.questions.count, imported.questions.count

    imported_question = imported.questions.first
    assert_nil imported_question.answer_value
    assert_nil imported_question.answered_at
    assert_equal({}, imported_question.answer_raw)
    assert_redirected_to event_questionnaire_url(@event, imported)
  end

  test "appends questions to existing questionnaire" do
    destination = @event.questionnaires.create!(title: "Existing Questionnaire")
    destination_section = destination.sections.first
    destination.questions.create!(prompt: "Existing question",
                                  response_type: "text",
                                  questionnaire_section: destination_section,
                                  position: 1)

    questions(:first).update!(answer_value: "Yes", answered_at: Time.current)

    assert_difference("Question.count", @source_questionnaire.questions.count) do
      post event_questionnaire_import_url(@event), params: {
        source_event_id: @source_event.id,
        source_questionnaire_id: @source_questionnaire.id,
        import_mode: "append",
        destination_questionnaire_id: destination.id
      }
    end

    destination.reload
    assert_equal 2, destination.sections.count
    assert_equal 2, destination.questions.count
    assert_nil destination.questions.order(:created_at).last.answer_value
    assert_redirected_to event_questionnaire_url(@event, destination)
  end
end
