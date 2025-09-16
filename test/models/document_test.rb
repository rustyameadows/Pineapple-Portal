require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "assigns logical id and version automatically" do
    event = events(:one)
    document = event.documents.create!(
      title: "Run of Show",
      storage_uri: "documents/run-of-show-v1.pdf",
      checksum: "checksum",
      size_bytes: 512,
      content_type: "application/pdf"
    )

    assert document.logical_id.present?
    assert_equal 1, document.version
    assert document.is_latest?
  end

  test "creating new version bumps version number and demotes previous latest" do
    event = events(:one)
    first = documents(:contract_v1)

    second = event.documents.create!(
      title: "Production Contract",
      storage_uri: "documents/contract-v2.pdf",
      checksum: "checksum-v2",
      size_bytes: 4096,
      content_type: "application/pdf",
      logical_id: first.logical_id
    )

    assert_equal 2, second.version
    assert second.is_latest?
    assert_not first.reload.is_latest?
  end

  test "file metadata cannot change after creation" do
    document = documents(:contract_v1)

    assert_raises ActiveRecord::RecordNotSaved do
      document.update!(storage_uri: "documents/contract-updated.pdf")
    end
  end
end
