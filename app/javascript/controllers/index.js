import { application } from "controllers/application"

import DecisionModalController from "controllers/decision_modal_controller"
import QuestionnaireController from "controllers/questionnaire_controller"
import QuestionAttachmentController from "controllers/question_attachment_controller"
import GeneratedSegmentsController from "controllers/generated_segments_controller"
import GeneratedMarkdownEditorController from "controllers/generated_markdown_editor_controller"
import EventSidebarController from "controllers/event_sidebar_controller"
import FlashToastController from "controllers/flash_toast_controller"
import RemoteOptionsController from "controllers/remote_options_controller"
import CustomSelectController from "controllers/custom_select_controller"

application.register("decision-modal", DecisionModalController)
application.register("questionnaire", QuestionnaireController)
application.register("question-attachment", QuestionAttachmentController)
application.register("generated-segments", GeneratedSegmentsController)
application.register("generated-markdown-editor", GeneratedMarkdownEditorController)
application.register("event-sidebar", EventSidebarController)
application.register("flash-toast", FlashToastController)
application.register("remote-options", RemoteOptionsController)
application.register("custom-select", CustomSelectController)
