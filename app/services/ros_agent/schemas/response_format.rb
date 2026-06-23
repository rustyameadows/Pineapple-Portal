module RosAgent
  module Schemas
    class ResponseFormat
      def self.for_mode(mode)
        {
          type: "json_schema",
          name: "ros_agent_#{mode.to_sym}_response",
          strict: true,
          schema: schema_for_mode(mode)
        }
      end

      def self.schema_for_mode(mode)
        mode.to_sym == :request_final_plan ? final_plan_schema : agent_turn_schema
      end

      def self.agent_turn_schema
        object_schema(
          required: %w[
            state summary source_understanding recommended_next_state questions draft_ros
            assumptions source_observations risk_notes review_notes suggested_next_questions
          ],
          properties: {
            state: { type: "string", enum: %w[source_understood needs_input draft_ready] },
            summary: string_schema,
            source_understanding: nullable(source_understanding_schema),
            recommended_next_state: nullable({ type: "string", enum: %w[needs_input drafting] }),
            questions: { type: "array", items: question_schema },
            draft_ros: nullable(draft_ros_schema),
            assumptions: string_array_schema,
            source_observations: string_array_schema,
            risk_notes: string_array_schema,
            review_notes: string_array_schema,
            suggested_next_questions: string_array_schema
          }
        )
      end

      def self.final_plan_schema
        object_schema(
          required: %w[state summary assumptions operations warnings review_highlights],
          properties: {
            state: { type: "string", enum: ["ready_for_review"] },
            summary: string_schema,
            assumptions: string_array_schema,
            operations: { type: "array", items: operation_schema },
            warnings: string_array_schema,
            review_highlights: string_array_schema
          }
        )
      end

      def self.source_understanding_schema
        object_schema(
          required: %w[
            source_title source_kind overall_read inferred_days reusable_patterns
            source_specific_details uncertainties confidence_notes source_evidence_refs
          ],
          properties: {
            source_title: string_schema,
            source_kind: string_schema,
            overall_read: string_schema,
            inferred_days: { type: "array", items: inferred_day_schema },
            reusable_patterns: string_array_schema,
            source_specific_details: { type: "array", items: source_specific_detail_schema },
            uncertainties: string_array_schema,
            confidence_notes: string_array_schema,
            source_evidence_refs: { type: "array", items: source_ref_schema }
          }
        )
      end

      def self.draft_ros_schema
        object_schema(
          required: %w[
            target_event_summary date_mapping draft_days draft_items assumptions
            review_flags refinement_notes source_references
          ],
          properties: {
            target_event_summary: string_schema,
            date_mapping: object_schema(
              required: ["source_days"],
              properties: {
                source_days: { type: "array", items: date_mapping_day_schema }
              }
            ),
            draft_days: {
              type: "array",
              items: object_schema(
                required: %w[label date],
                properties: {
                  label: string_schema,
                  date: nullable(string_schema)
                }
              )
            },
            draft_items: { type: "array", items: draft_item_schema },
            assumptions: string_array_schema,
            review_flags: string_array_schema,
            refinement_notes: string_array_schema,
            source_references: { type: "array", items: source_ref_schema }
          }
        )
      end

      def self.question_schema
        object_schema(
          required: %w[key label question why_it_matters required answer_type options freeform_allowed],
          properties: {
            key: string_schema,
            label: string_schema,
            question: string_schema,
            why_it_matters: string_schema,
            required: { type: "boolean" },
            answer_type: { type: "string", enum: QuestionBatchSchema::ANSWER_TYPES },
            options: { type: "array", items: question_option_schema },
            freeform_allowed: { type: "boolean" }
          }
        )
      end

      def self.inferred_day_schema
        object_schema(
          required: %w[source_label role confidence notes],
          properties: {
            source_label: string_schema,
            role: string_schema,
            confidence: { type: "string", enum: SourceUnderstandingSchema::CONFIDENCE_VALUES },
            notes: string_schema
          }
        )
      end

      def self.source_specific_detail_schema
        object_schema(
          required: %w[detail recommended_action reason],
          properties: {
            detail: string_schema,
            recommended_action: string_schema,
            reason: string_schema
          }
        )
      end

      def self.date_mapping_day_schema
        object_schema(
          required: %w[source_label target_date],
          properties: {
            source_label: string_schema,
            target_date: nullable(string_schema)
          }
        )
      end

      def self.question_option_schema
        object_schema(
          required: %w[value label recommended description],
          properties: {
            value: string_schema,
            label: string_schema,
            recommended: { type: "boolean" },
            description: string_schema
          }
        )
      end

      def self.draft_item_schema
        object_schema(
          required: %w[
            title timing duration_minutes confidence source_refs details
          ],
          properties: {
            title: string_schema,
            timing: object_schema(
              required: %w[kind starts_at relative_anchor_title relative_offset_minutes],
              properties: {
                kind: string_schema,
                starts_at: nullable(string_schema),
                relative_anchor_title: nullable(string_schema),
                relative_offset_minutes: nullable(integer_schema)
              }
            ),
            duration_minutes: nullable(integer_schema),
            confidence: { type: "string", enum: DraftRosSchema::CONFIDENCE_VALUES },
            source_refs: { type: "array", items: source_ref_schema },
            details: { type: "array", items: draft_item_detail_schema }
          }
        )
      end

      def self.draft_item_detail_schema
        object_schema(
          required: %w[field value source_refs],
          properties: {
            field: { type: "string", enum: DraftRosSchema::DETAIL_FIELDS },
            value: string_schema,
            source_refs: { type: "array", items: source_ref_schema }
          }
        )
      end

      def self.operation_schema
        object_schema(
          required: %w[
            operation_id operation_type summary risk_level source_refs item_attributes
            target_item_id target_item_operation_id tag_ids tag_names name color_token reasoning_summary
          ],
          properties: {
            operation_id: string_schema,
            operation_type: { type: "string", enum: ChangePlanSchema::OPERATION_TYPES },
            summary: string_schema,
            risk_level: { type: "string", enum: ChangePlanSchema::RISK_LEVELS },
            source_refs: { type: "array", items: source_ref_schema },
            item_attributes: item_attributes_schema,
            target_item_id: nullable(integer_schema),
            target_item_operation_id: nullable(string_schema),
            tag_ids: { type: "array", items: integer_schema },
            tag_names: string_array_schema,
            name: nullable(string_schema),
            color_token: nullable(string_schema),
            reasoning_summary: string_schema
          }
        )
      end

      def self.item_attributes_schema
        object_schema(
          required: %w[
            title notes starts_at duration_minutes vendor_name location_name time_caption
            transportation_note guest_count additional_team_members relative_anchor_id
            relative_offset_minutes relative_before relative_to_anchor_end locked status
          ],
          properties: {
            title: nullable(string_schema),
            notes: nullable(string_schema),
            starts_at: nullable(string_schema),
            duration_minutes: nullable(integer_schema),
            vendor_name: nullable(string_schema),
            location_name: nullable(string_schema),
            time_caption: nullable(string_schema),
            transportation_note: nullable(string_schema),
            guest_count: nullable(integer_schema),
            additional_team_members: nullable(string_schema),
            relative_anchor_id: nullable(integer_schema),
            relative_offset_minutes: nullable(integer_schema),
            relative_before: nullable({ type: "boolean" }),
            relative_to_anchor_end: nullable({ type: "boolean" }),
            locked: nullable({ type: "boolean" }),
            status: nullable(string_schema)
          }
        )
      end

      def self.source_ref_schema
        object_schema(
          required: %w[artifact locator],
          properties: {
            artifact: string_schema,
            locator: string_schema
          }
        )
      end

      def self.object_schema(required:, properties:)
        {
          type: "object",
          additionalProperties: false,
          required: required,
          properties: properties.stringify_keys
        }
      end

      def self.string_schema
        { type: "string" }
      end

      def self.integer_schema
        { type: "integer" }
      end

      def self.string_array_schema
        { type: "array", items: string_schema }
      end

      def self.nullable(schema)
        { anyOf: [schema, { type: "null" }] }
      end
    end
  end
end
