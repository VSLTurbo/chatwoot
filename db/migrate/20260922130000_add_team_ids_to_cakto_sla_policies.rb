class AddTeamIdsToCaktoSlaPolicies < ActiveRecord::Migration[7.1]
  def change
    add_column :cakto_sla_policies, :team_ids, :integer, array: true, default: [], null: false
  end
end
