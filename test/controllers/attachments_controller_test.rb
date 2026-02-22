require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:one)
    @questionnaire = questionnaires(:checklist)
    @document = documents(:contract_v1)
  end

  test "creates attachment" do
    assert_difference("Attachment.count") do
      post attachments_url, params: {
        attachment: {
          entity_type: "Question",
          entity_id: questions(:first).id,
          document_id: @document.id
        }
      }
    end

    assert_redirected_to root_url
  end

  test "uploads new document for attachment" do
    assert_difference(["Document.count", "Attachment.count"]) do
      post attachments_url, params: {
        attachment: {
          entity_type: "Question",
          entity_id: questions(:first).id,
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

  test "creates attachment for approval with context forced to other" do
    approval = @event.approvals.create!(
      title: "Layout Approval",
      client_visible: true,
      status: :pending
    )

    assert_difference("Attachment.count") do
      post attachments_url, params: {
        attachment: {
          entity_type: "Approval",
          entity_id: approval.id,
          document_id: @document.id,
          context: "answer"
        }
      }
    end

    attachment = Attachment.order(:created_at).last
    assert_equal approval, attachment.entity
    assert_equal "other", attachment.context
    assert_equal @document, attachment.document
  end

  test "uploads new document and attaches it to approval" do
    approval = @event.approvals.create!(
      title: "Menu Approval",
      client_visible: true,
      status: :pending
    )

    assert_difference(["Document.count", "Attachment.count"]) do
      post attachments_url, params: {
        attachment: {
          entity_type: "Approval",
          entity_id: approval.id,
          file_upload_title: "Approval Upload.pdf",
          file_upload_storage_uri: "documents/#{@event.id}/abc/v1/approval-upload.pdf",
          file_upload_checksum: "feedbeef",
          file_upload_size_bytes: "1024",
          file_upload_content_type: "application/pdf",
          file_upload_logical_id: SecureRandom.uuid
        }
      }
    end

    attachment = Attachment.order(:created_at).last
    assert_equal approval, attachment.entity
    assert_equal "other", attachment.context
    assert attachment.document.present?
    assert_equal @event, attachment.document.event
  end

  test "removes attachment" do
    attachment = attachments(:checklist_answer_attachment)

    assert_difference("Attachment.count", -1) do
      delete attachment_url(attachment)
    end

    assert_redirected_to root_url
  end
end
