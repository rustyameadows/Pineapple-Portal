class BackfillEventTeamMemberVisibility < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    say_with_time "Marking existing event team members as client visible" do
      EventTeamMember.update_all(client_visible: true)
    end
  end

  def down
    # irreversible
  end
end
