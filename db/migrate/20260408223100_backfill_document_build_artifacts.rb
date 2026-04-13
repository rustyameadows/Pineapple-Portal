class BackfillDocumentBuildArtifacts < ActiveRecord::Migration[8.0]
  class MigrationDocument < ActiveRecord::Base
    self.table_name = "documents"
  end

  class MigrationDocumentBuild < ActiveRecord::Base
    self.table_name = "document_builds"
  end

  def up
    MigrationDocument.reset_column_information
    MigrationDocumentBuild.reset_column_information

    say_with_time "Backfilling snapshot build artifacts" do
      MigrationDocument.where.not(build_id: nil).where.not(storage_uri: nil).find_each do |document|
        build = MigrationDocumentBuild.find_by(build_id: document.build_id)
        next unless build

        updates = {}
        updates[:storage_uri] = document.storage_uri if build.storage_uri.blank?
        updates[:manifest_hash] = document.manifest_hash if build.manifest_hash.blank?
        next if updates.empty?

        build.update_columns(updates)
      end
    end

    say_with_time "Backfilling live working PDFs into working builds" do
      MigrationDocument.where(doc_kind: "generated", storage_uri: nil)
                       .where.not(working_storage_uri: nil)
                       .find_each do |document|
        next if MigrationDocumentBuild.where(document_id: document.id, build_kind: "working").exists?

        rendered_at = document.working_rendered_at ||
                      document.working_refresh_started_at ||
                      document.working_refresh_requested_at ||
                      document.updated_at ||
                      Time.current

        MigrationDocumentBuild.create!(
          document_id: document.id,
          status: "succeeded",
          build_kind: "working",
          build_id: SecureRandom.uuid,
          compiled_page_count: document.working_page_count,
          file_size: document.working_file_size,
          checksum_sha256: document.working_checksum_sha256,
          started_at: rendered_at,
          finished_at: rendered_at,
          built_by_user_id: document.built_by_user_id,
          created_at: rendered_at,
          updated_at: rendered_at,
          storage_uri: document.working_storage_uri,
          manifest_hash: document.working_manifest_hash,
          page_numbers: true
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
