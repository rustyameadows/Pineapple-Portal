import { application } from "controllers/application"

import DecisionModalController from "controllers/decision_modal_controller"
import QuestionnaireController from "controllers/questionnaire_controller"

application.register("decision-modal", DecisionModalController)
application.register("questionnaire", QuestionnaireController)
