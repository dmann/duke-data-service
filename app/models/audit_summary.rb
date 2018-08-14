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
    if audit.action == "create"
      self.created_by = audit.user
      self.created_on = audit.created_at
    else
      self.last_updated_by = audit.user
      self.last_updated_on = audit.created_at
      if audit.comment['action'] == 'DELETE' &&
          audit.audited_changes['is_deleted'][1]
        self.deleted_by = audit.user
        self.deleted_on = audit.created_at
      end
    end
  end
end
