require "test_helper"

class AttachmentTest < ActiveSupport::TestCase
  test "requires exactly one document reference" do
    questionnaire = questionnaires(:checklist)
    attachment = Attachment.new(entity: questionnaire, context: :prompt, position: 2)

    assert_not attachment.valid?
    assert_includes attachment.errors[:base], "Document reference is required"

    attachment.document = documents(:contract_v1)
    attachment.document_logical_id = documents(:contract_v1).logical_id

    assert_not attachment.valid?
    assert_includes attachment.errors[:base], "Specify either document or document_logical_id, not both"
  end
end
