require 'rails_helper'

RSpec.describe AuditSummary, type: :model do
  it { is_expected.to belong_to(:auditable) }
  it { is_expected.to belong_to(:created_by).class_name('User') }
  it { is_expected.to belong_to(:last_updated_by).class_name('User') }
  it { is_expected.to belong_to(:deleted_by).class_name('User') }
  it { is_expected.to belong_to(:restored_by).class_name('User') }
  it { is_expected.to belong_to(:purged_by).class_name('User') }
end
