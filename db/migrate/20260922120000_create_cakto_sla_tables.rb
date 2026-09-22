class CreateCaktoSlaTables < ActiveRecord::Migration[7.1]
  def change
    create_cakto_sla_policies
    create_cakto_conversation_slas
    add_cakto_conversation_sla_indexes
  end

  private

  def create_cakto_sla_policies
    create_table :cakto_sla_policies do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description
      t.integer :first_response_minutes
      t.integer :resolution_minutes
      t.integer :inbox_ids, array: true, default: [], null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end

  def create_cakto_conversation_slas
    create_table :cakto_conversation_slas do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :cakto_sla_policy, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :first_response_due_at
      t.datetime :resolution_due_at
      t.integer :first_response_status, default: 0, null: false
      t.integer :resolution_status, default: 0, null: false
      t.datetime :first_response_met_at
      t.datetime :resolution_met_at
      t.datetime :breached_at

      t.timestamps
    end
  end

  def add_cakto_conversation_sla_indexes
    add_index :cakto_conversation_slas, [:account_id, :first_response_status]
    add_index :cakto_conversation_slas, [:account_id, :resolution_status]
    add_index :cakto_conversation_slas, :first_response_due_at
    add_index :cakto_conversation_slas, :resolution_due_at
  end
end
