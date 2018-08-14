class AuditSummary < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :last_updated_by, class_name: 'User'
  belongs_to :deleted_by, class_name: 'User'
  belongs_to :restored_by, class_name: 'User'
  belongs_to :purged_by, class_name: 'User'

  def set_attributes_from_audit(audit)
    raise 'Audit cannot be nil' if audit.nil?
    raise 'Audit parameter must be of type Audit' unless audit.is_a? Audited::Audit
    raise 'Audit is associated with a different auditable object' if auditable && auditable != audit.auditable
    self.auditable = audit.auditable
    self.created_by = audit.user
    self.created_on = audit.created_at
  end
end
