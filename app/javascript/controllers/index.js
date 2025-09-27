import { application } from "controllers/application"

import DecisionModalController from "controllers/decision_modal_controller"
import QuestionnaireController from "controllers/questionnaire_controller"
import QuestionAttachmentController from "controllers/question_attachment_controller"

application.register("decision-modal", DecisionModalController)
application.register("questionnaire", QuestionnaireController)
application.register("question-attachment", QuestionAttachmentController)
