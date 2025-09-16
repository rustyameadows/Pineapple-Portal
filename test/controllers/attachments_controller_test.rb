require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @questionnaire = questionnaires(:checklist)
    @document = documents(:contract_v1)
  end

  test "creates attachment" do
    assert_difference("Attachment.count") do
      post attachments_url, params: {
        attachment: {
          entity_type: "Questionnaire",
          entity_id: @questionnaire.id,
          document_id: @document.id,
          context: "help_text",
          position: 2
        }
      }
    end

    assert_redirected_to root_url
  end

  test "removes attachment" do
    attachment = attachments(:checklist_prompt)

    assert_difference("Attachment.count", -1) do
      delete attachment_url(attachment)
    end

    assert_redirected_to root_url
  end
end
