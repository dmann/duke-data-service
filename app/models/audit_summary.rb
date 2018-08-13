class AuditSummary < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :last_updated_by, class_name: 'User'
  belongs_to :deleted_by, class_name: 'User'
  belongs_to :restored_by, class_name: 'User'
  belongs_to :purged_by, class_name: 'User'
end
