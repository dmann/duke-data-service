require 'rails_helper'

RSpec.describe AuditSummary, type: :model do
  it { is_expected.to belong_to(:auditable) }
  it { is_expected.to belong_to(:created_by).class_name('User') }
  it { is_expected.to belong_to(:last_updated_by).class_name('User') }
  it { is_expected.to belong_to(:deleted_by).class_name('User') }
  it { is_expected.to belong_to(:restored_by).class_name('User') }
  it { is_expected.to belong_to(:purged_by).class_name('User') }

  describe '#set_attributes_from_audit' do
    subject { FactoryBot.create(:audit_summary, :with_auditable) }
    let(:another_audit_summary) { FactoryBot.create(:audit_summary, :with_auditable) }
    let(:audit) { subject.auditable.audits.first }
    let(:call_method) { subject.set_attributes_from_audit(audit) }

    it { is_expected.to respond_to(:set_attributes_from_audit).with(1).argument }
    it { expect{ call_method }.not_to raise_error }

    context 'with nil parameter' do
      let(:audit) { nil }
      it 'raises excpetion and remains unchanged' do
        expect{ call_method }.to raise_error 'Audit cannot be nil'
        is_expected.not_to be_changed
      end
    end

    context 'with non-Audit parameter' do
      let(:audit) { another_audit_summary }
      it 'raises excpetion and remains unchanged' do
        expect{ call_method }.to raise_error 'Audit parameter must be of type Audit'
        is_expected.not_to be_changed
      end
    end

    context 'when Audit has different auditable' do
      let(:audit) { another_audit_summary.auditable.audits.first }
      it 'raises excpetion and remains unchanged' do
        expect{ call_method }.to raise_error 'Audit is associated with a different auditable object'
        is_expected.not_to be_changed
      end
    end

    context 'when auditable is not set' do
      subject { FactoryBot.create(:audit_summary) }
      let(:audit) { another_audit_summary.auditable.audits.first }

      it 'sets auditable to audit.auditable' do
        expect(subject.auditable).to be_nil
        expect{ call_method }.not_to raise_error
        expect(subject.auditable).to eq audit.auditable
      end

      context 'with nil parameter' do
        let(:audit) { nil }
        it 'raises excpetion and remains unchanged' do
          expect{ call_method }.to raise_error 'Audit cannot be nil'
          is_expected.not_to be_changed
        end
      end

      context 'with non-Audit parameter' do
        let(:audit) { another_audit_summary }
        it 'raises excpetion and remains unchanged' do
          expect{ call_method }.to raise_error 'Audit parameter must be of type Audit'
          is_expected.not_to be_changed
        end
      end
    end
  end
end
