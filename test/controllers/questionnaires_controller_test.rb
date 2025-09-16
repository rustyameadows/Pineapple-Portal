require "test_helper"

class QuestionnairesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:one)
  end

  test "creates questionnaire" do
    assert_difference("Questionnaire.count") do
      post event_questionnaires_url(@event), params: { questionnaire: { title: "AV Checklist", description: "Audio/visual checks" } }
    end

    assert_redirected_to questionnaire_url(Questionnaire.last)
  end

  test "lists templates" do
    get questionnaire_templates_url
    assert_response :success
    assert_select "h1", text: "Template Questionnaires"
  end
end
