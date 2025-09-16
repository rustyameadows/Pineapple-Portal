users = [
  { name: "Ada Lovelace", email: "ada@example.com" },
  { name: "Grace Hopper", email: "grace@example.com" }
]

users.each do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |user|
    user.name = attrs[:name]
    user.password = "password123"
  end
end

event = Event.find_or_create_by!(name: "Sample Launch Event") do |evt|
  evt.starts_on = Date.today
  evt.ends_on = Date.today + 1
  evt.location = "Main Stage"
end

questionnaire = event.questionnaires.find_or_create_by!(title: "Kickoff Checklist") do |form|
  form.description = "Confirm initial logistics for the event."
end

question = questionnaire.questions.find_or_create_by!(prompt: "Confirm venue booking is complete.") do |question|
  question.help_text = "Include reservation number and point of contact."
  question.response_type = "text"
end

template_questionnaire = event.questionnaires.find_or_create_by!(title: "Post-Event Survey Template") do |form|
  form.description = "Standard questions for attendee follow up."
  form.is_template = true
end

document = event.documents.find_or_create_by!(title: "Production Contract", storage_uri: "documents/sample-contract-v1.pdf") do |doc|
  doc.content_type = "application/pdf"
  doc.checksum = "demo-checksum"
  doc.size_bytes = 1024
end

Attachment.find_or_create_by!(entity: question, document: document, context: :answer, position: 1) do |attachment|
  attachment.notes = "Reference contract details while completing this checklist."
end
