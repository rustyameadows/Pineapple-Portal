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

  test "uploads new document for attachment" do
    assert_difference(["Document.count", "Attachment.count"]) do
      post attachments_url, params: {
        attachment: {
          entity_type: "Questionnaire",
          entity_id: @questionnaire.id,
          context: "answer",
          position: 1,
          file_upload_title: "Answer Sheet.pdf",
          file_upload_storage_uri: "documents/#{@questionnaire.event.id}/abc/v1/answer-sheet.pdf",
          file_upload_checksum: "deadbeef",
          file_upload_size_bytes: "2048",
          file_upload_content_type: "application/pdf",
          file_upload_logical_id: SecureRandom.uuid
        }
      }
    end

    attachment = Attachment.order(:created_at).last
    assert_equal "answer", attachment.context
    assert attachment.document.present?
  end

  test "removes attachment" do
    attachment = attachments(:checklist_prompt)

    assert_difference("Attachment.count", -1) do
      delete attachment_url(attachment)
    end

    assert_redirected_to root_url
  end
end
