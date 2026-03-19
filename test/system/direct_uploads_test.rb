require "application_system_test_case"
require "json"
require "timeout"

class DirectUploadsTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @user = users(:one)
    @fixture_path = Rails.root.join("test/fixtures/files/upload-sample.txt")
  end

  test "document upload populates metadata and saves successfully" do
    login_as_planner
    visit new_event_document_path(@event)

    install_direct_upload_mocks(
      presignPath: presign_event_documents_path(@event),
      uploadUrl: "https://r2.example.test/upload/document",
      storageUri: "documents/#{@event.id}/logical-doc/v1/upload-sample.txt",
      logicalId: "logical-doc"
    )

    assert_difference("Document.count", 1) do
      attach_file("document_file", @fixture_path, make_visible: true)

      assert_text "Upload ready. Click Save to store document metadata."
      assert_equal "documents/#{@event.id}/logical-doc/v1/upload-sample.txt", page.find("#document_storage_uri", visible: false).value
      assert_equal "text/plain", page.find("#document_content_type", visible: false).value
      assert_equal "logical-doc", page.find("#document_logical_id", visible: false).value
      assert_selector "[data-document-upload-form] input[type='submit']:not([disabled])"

      within "[data-document-upload-form]" do
        click_button "Create Document"
      end

      assert_text "Document saved."
    end

    assert_equal "upload-sample.txt", Document.order(:created_at).last.title
  end

  test "approval attachment upload saves a new attachment" do
    approval = @event.approvals.create!(
      title: "Menu Approval",
      client_visible: true,
      status: :pending
    )

    login_as_planner
    visit event_approval_path(@event, approval)

    install_direct_upload_mocks(
      presignPath: presign_event_documents_path(@event),
      uploadUrl: "https://r2.example.test/upload/attachment",
      storageUri: "documents/#{@event.id}/logical-attachment/v1/upload-sample.txt",
      logicalId: "logical-attachment"
    )

    assert_difference(["Document.count", "Attachment.count"], 1) do
      attach_file("attachment_file_#{approval.id}", @fixture_path, make_visible: true)

      assert_text "File uploaded. Add notes and click Add Attachment."
      assert_selector "[data-attachment-upload-form] input[type='submit']:not([disabled])"

      within "[data-attachment-upload-form]" do
        click_button "Add Attachment"
      end

      assert_text "Attachment added."
    end

    attachment = Attachment.order(:created_at).last
    assert_equal approval, attachment.entity
    assert_equal @event, attachment.document.event
  end

  test "failed storage upload shows detailed error and reports it server side" do
    reported = []
    subscriber = ActiveSupport::Notifications.subscribe("direct_upload.failure_reported") do |_name, _start, _finish, _id, payload|
      reported << payload
    end

    login_as_planner
    visit new_event_document_path(@event)

    install_direct_upload_mocks(
      presignPath: presign_event_documents_path(@event),
      uploadUrl: "https://r2.example.test/upload/document",
      storageUri: "documents/#{@event.id}/logical-failure/v1/upload-sample.txt",
      logicalId: "logical-failure",
      failUpload: true
    )

    attach_file("document_file", @fixture_path, make_visible: true)

    assert_text "Upload to storage was blocked before it completed. This usually points to a storage CORS or network issue."
    assert_selector "[data-document-upload-form] input[type='submit'][disabled]"

    Timeout.timeout(5) do
      sleep 0.05 until reported.any?
    end

    assert_equal "document_form", reported.last[:scope]
    assert_equal "storage_put", reported.last[:stage]
    assert_equal "logical-failure", reported.last[:logical_id]
    assert_equal "documents/#{@event.id}/logical-failure/v1/upload-sample.txt", reported.last[:storage_uri]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_text "Your Active Events"
  end

  def install_direct_upload_mocks(presignPath:, uploadUrl:, storageUri:, logicalId:, failUpload: false)
    execute_script(<<~JS, presignPath, uploadUrl, storageUri, logicalId, failUpload)
      ((presignPath, uploadUrl, storageUri, logicalId, failUpload) => {
        window.__directUploadMock = {
          presignPath,
          uploadUrl,
          storageUri,
          logicalId,
          failUpload
        };

        const originalFetch = window.fetch.bind(window);
        window.fetch = async (input, init = {}) => {
          const requestUrl = typeof input === "string" ? input : input.url;
          const pathname = new URL(requestUrl, window.location.origin).pathname;

          if (pathname === presignPath) {
            return new Response(JSON.stringify({
              upload_url: uploadUrl,
              storage_uri: storageUri,
              logical_id: logicalId,
              version: 1,
              content_type: "text/plain"
            }), {
              status: 200,
              headers: { "Content-Type": "application/json" }
            });
          }

          return originalFetch(input, init);
        };

        class FakeXHR {
          constructor() {
            this.headers = {};
            this.listeners = {};
            this.upload = {
              addEventListener: (name, callback) => {
                this.listeners[`upload:${name}`] = callback;
              }
            };
            this.readyState = 0;
            this.status = 0;
            this.responseText = "";
          }

          open(method, url) {
            this.method = method;
            this.url = url;
          }

          setRequestHeader(name, value) {
            this.headers[name] = value;
          }

          addEventListener(name, callback) {
            this.listeners[name] = callback;
          }

          send(file) {
            const progress = this.listeners["upload:progress"];
            if (progress) {
              progress({ loaded: file.size, total: file.size, lengthComputable: true });
            }

            if (this.url !== uploadUrl) {
              this.status = 404;
              this.responseText = "Unexpected upload URL";
              if (this.listeners.load) this.listeners.load();
              return;
            }

            if (failUpload) {
              this.status = 0;
              this.responseText = "";
              if (this.listeners.error) this.listeners.error();
              return;
            }

            this.status = 200;
            this.responseText = "";
            if (this.listeners.load) this.listeners.load();
          }

          getResponseHeader() {
            return null;
          }
        }

        window.XMLHttpRequest = FakeXHR;
      })(...arguments)
    JS
  end
end
