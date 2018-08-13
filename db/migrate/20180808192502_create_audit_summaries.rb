class CreateAuditSummaries < ActiveRecord::Migration[5.1]
  def change
    create_table :audit_summaries, id: :uuid do |t|
      t.string :auditable_type
      t.uuid :auditable_id
      t.datetime :created_on
      t.uuid :created_by_id
      t.datetime :last_updated_on
      t.uuid :last_updated_by_id
      t.datetime :deleted_on
      t.uuid :deleted_by_id
      t.datetime :restored_on
      t.uuid :restored_by_id
      t.datetime :purged_on
      t.uuid :purged_by_id
    end

    add_index :audit_summaries, [:auditable_type, :auditable_id], :name => 'as_auditable_index'
  end
end
