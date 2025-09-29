module EventsHelper
  def event_sidebar_sections(event)
    run_of_show = event.run_of_show_calendar
    derived_views = Array(run_of_show&.event_calendar_views&.order(:position, :name))
    generated_documents = event.documents.generated.latest.order(:title)
    questionnaires = event.questionnaires.order(:title)
    payments = event.payments.ordered
    approvals = event.approvals.ordered

    sections = []

    sections << {
      id: :event_info,
      label: "Event Info",
      path: event_settings_path(event),
      sub_links: [
        { label: "General Info", path: event_settings_path(event) },
        { label: "Client Portal", path: client_portal_event_settings_path(event) },
        { label: "Clients", path: clients_event_settings_path(event) },
        { label: "Vendors", path: vendors_event_settings_path(event) },
        { label: "Locations", path: locations_event_settings_path(event) },
        { label: "Planners", path: planners_event_settings_path(event) }
      ],
      match_paths: [
        event_settings_path(event),
        client_portal_event_settings_path(event),
        clients_event_settings_path(event),
        vendors_event_settings_path(event),
        locations_event_settings_path(event),
        planners_event_settings_path(event)
      ]
    }

    timeline_sub_links = []
    if run_of_show
      timeline_sub_links << { label: "Run of Show Calendar", path: event_calendar_path(event) }
    else
      timeline_sub_links << { label: "Run of Show Calendar", path: nil, stub: true }
    end

    if derived_views.any?
      timeline_sub_links.concat(
        derived_views.map do |view|
          { label: view.name, path: event_calendar_view_path(event, view) }
        end
      )
    else
      timeline_sub_links << { label: "No derived views yet", path: nil, stub: true }
    end

    timeline_match_paths = [event_calendars_path(event), event_calendar_path(event)] +
      derived_views.map { |view| event_calendar_view_path(event, view) }

    sections << {
      id: :timeline,
      label: "Timeline",
      path: event_calendars_path(event),
      sub_links: timeline_sub_links,
      match_paths: timeline_match_paths
    }

    packet_sub_links = if generated_documents.any?
                         generated_documents.map do |document|
                           {
                             label: document.title,
                             path: event_documents_generated_path(event, document.logical_id)
                           }
                         end
                       else
                         [{ label: "No packets yet", path: nil, stub: true }]
                       end

    sections << {
      id: :packets,
      label: "Packets",
      path: event_documents_generated_index_path(event),
      sub_links: packet_sub_links,
      match_paths: [event_documents_generated_index_path(event)] +
        generated_documents.map { |document| event_documents_generated_path(event, document.logical_id) }
    }

    upload_sub_links = [
      { label: "Your Uploads", path: staff_uploads_event_documents_path(event) },
      { label: "Client Uploads", path: client_uploads_event_documents_path(event) },
      { label: "Upload Doc", path: new_event_document_path(event) }
    ]

    sections << {
      id: :uploads,
      label: "Uploads",
      path: event_documents_path(event),
      sub_links: upload_sub_links,
      match_paths: [
        event_documents_path(event),
        staff_uploads_event_documents_path(event),
        client_uploads_event_documents_path(event),
        new_event_document_path(event)
      ]
    }

    sections << {
      id: :people,
      label: "People",
      path: event_people_path(event),
      sub_links: [
        { label: "Directory", path: event_people_path(event) },
        { label: "Guest List", path: nil, stub: true }
      ],
      match_paths: [event_people_path(event)]
    }

    questionnaire_sub_links = if questionnaires.any?
                                questionnaires.map do |questionnaire|
                                  {
                                    label: questionnaire.title,
                                    path: event_questionnaire_path(event, questionnaire)
                                  }
                                end
                              else
                                [{ label: "No questionnaires yet", path: nil, stub: true }]
                              end

    sections << {
      id: :questionnaires,
      label: "Questionnaires",
      path: event_questionnaires_path(event),
      sub_links: questionnaire_sub_links,
      match_paths: [event_questionnaires_path(event)] +
        questionnaires.map { |questionnaire| event_questionnaire_path(event, questionnaire) }
    }

    payment_sub_links = if payments.any?
                          payments.map do |payment|
                            label = payment.title
                            label += " · Due #{payment.due_on.to_fs(:short)}" if payment.due_on.present?
                            {
                              label:,
                              path: event_payment_path(event, payment)
                            }
                          end
                        else
                          [{ label: "No payments yet", path: nil, stub: true }]
                        end

    sections << {
      id: :payments,
      label: "Payments",
      path: event_payments_path(event),
      sub_links: payment_sub_links,
      match_paths: [event_payments_path(event)] +
        payments.map { |payment| event_payment_path(event, payment) }
    }

    approval_sub_links = if approvals.any?
                           approvals.map do |approval|
                             {
                               label: approval.title,
                               path: event_approval_path(event, approval)
                             }
                           end
                         else
                           [{ label: "No approvals yet", path: nil, stub: true }]
                         end

    sections << {
      id: :approvals,
      label: "Approvals",
      path: event_approvals_path(event),
      sub_links: approval_sub_links,
      match_paths: [event_approvals_path(event)] +
        approvals.map { |approval| event_approval_path(event, approval) }
    }

    sections
  end

  def event_sidebar_secondary_links
    [
      { label: "All Events", path: events_path },
      { label: "Pineapple Team", path: users_path }
    ]
  end

  def event_sidebar_section_active?(section, current_path)
    paths = Array(section[:match_paths])
    paths += section.fetch(:sub_links, []).map { |link| link[:path] }
    paths.compact.any? { |path| sidebar_path_match?(current_path, path) }
  end

  private

  def sidebar_path_match?(current_path, target_path)
    return false if target_path.blank?

    return true if current_path == target_path

    prefix = "#{target_path}/"
    return false unless current_path.start_with?(prefix)

    remainder = current_path.delete_prefix(prefix)
    first_segment = remainder.split("/").first

    if first_segment == "generated" && !target_path.include?("/generated")
      return false
    end

    true
  end
end
