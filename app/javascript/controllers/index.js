import { application } from "controllers/application"

import DecisionModalController from "controllers/decision_modal_controller"
import QuestionnaireController from "controllers/questionnaire_controller"
import QuestionAttachmentController from "controllers/question_attachment_controller"
import GeneratedSegmentsController from "controllers/generated_segments_controller"
import GeneratedSegmentDialogController from "controllers/generated_segment_dialog_controller"
import GeneratedMarkdownEditorController from "controllers/generated_markdown_editor_controller"
import GeneratedPacketUploadController from "controllers/generated_packet_upload_controller"
import GeneratedPdfFrameController from "controllers/generated_pdf_frame_controller"
import DocumentBuildStatusController from "controllers/document_build_status_controller"
import LocalTimeController from "controllers/local_time_controller"
import EventSidebarController from "controllers/event_sidebar_controller"
import EventGroupSelectController from "controllers/event_group_select_controller"
import CalendarBulkEditController from "controllers/calendar_bulk_edit_controller"
import CalendarItemImportController from "controllers/calendar_item_import_controller"
import AnchorScrollController from "controllers/anchor_scroll_controller"
import FlashToastController from "controllers/flash_toast_controller"
import RemoteOptionsController from "controllers/remote_options_controller"
import CustomSelectController from "controllers/custom_select_controller"
import DocumentBrowserController from "controllers/document_browser_controller"
import LocalSelectController from "controllers/local_select_controller"
import RosAgentTaskController from "controllers/ros_agent_task_controller"
import RosAgentStatusController from "controllers/ros_agent_status_controller"

application.register("decision-modal", DecisionModalController)
application.register("questionnaire", QuestionnaireController)
application.register("question-attachment", QuestionAttachmentController)
application.register("generated-segments", GeneratedSegmentsController)
application.register("generated-segment-dialog", GeneratedSegmentDialogController)
application.register("generated-markdown-editor", GeneratedMarkdownEditorController)
application.register("generated-packet-upload", GeneratedPacketUploadController)
application.register("generated-pdf-frame", GeneratedPdfFrameController)
application.register("document-build-status", DocumentBuildStatusController)
application.register("local-time", LocalTimeController)
application.register("event-sidebar", EventSidebarController)
application.register("event-group-select", EventGroupSelectController)
application.register("calendar-bulk-edit", CalendarBulkEditController)
application.register("calendar-item-import", CalendarItemImportController)
application.register("anchor-scroll", AnchorScrollController)
application.register("flash-toast", FlashToastController)
application.register("remote-options", RemoteOptionsController)
application.register("custom-select", CustomSelectController)
application.register("document-browser", DocumentBrowserController)
application.register("local-select", LocalSelectController)
application.register("ros-agent-task", RosAgentTaskController)
application.register("ros-agent-status", RosAgentStatusController)
