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
    let(:auditable) { subject.auditable }
    let(:audit) { auditable.audits.first }
    let(:call_method) { subject.set_attributes_from_audit(audit) }
    let(:audit_user) { FactoryBot.create(:user) }

    around(:each) do |example|
      Audited.audit_class.as_user(audit_user) do
        example.run
      end
    end

    it { is_expected.to respond_to(:set_attributes_from_audit).with(1).argument }
    it { expect{ call_method }.not_to raise_error }

    context 'when audit action is "create"' do
      before(:each) do
        expect(audit.action).to eq 'create'
        expect(audit.user).not_to be_nil
        expect(audit.created_at).not_to be_nil
        expect{ call_method }.not_to raise_error
      end
      it { expect(subject.changed).to match_array ["created_by_id", "created_on"] }
      it { expect(subject.created_by).to eq audit.user }
      it { expect(subject.created_on).to eq audit.created_at }
    end

    context 'when audit action is "update"' do
      let(:audit) { auditable.audits.second }
      before(:each) do
        expect(auditable.update(display_name: 'foo')).to be_truthy
        expect(audit.action).to eq 'update'
        expect(audit.user).not_to be_nil
        expect(audit.created_at).not_to be_nil
        expect{ call_method }.not_to raise_error
      end
      it { expect(subject.changed).to match_array ["last_updated_by_id", "last_updated_on"] }
      it { expect(subject.last_updated_by).to eq audit.user }
      it { expect(subject.last_updated_on).to eq audit.created_at }
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

    context 'when Audit has different auditable' do
      let(:audit) { another_audit_summary.auditable.audits.first }
      it 'raises excpetion and remains unchanged' do
        expect{ call_method }.to raise_error 'Audit is associated with a different auditable object'
        is_expected.not_to be_changed
      end
    end

    context 'when auditable is not set' do
      subject { FactoryBot.create(:audit_summary) }
      let(:auditable) { another_audit_summary.auditable }

      it 'sets auditable to audit.auditable' do
        expect(subject.auditable).to be_nil
        expect{ call_method }.not_to raise_error
        expect(subject.auditable).to eq audit.auditable
      end

      context 'when audit action is "create"' do
        before(:each) do
          expect(audit.action).to eq 'create'
          expect(audit.user).not_to be_nil
          expect{ call_method }.not_to raise_error
        end
        it { expect(subject.changed).to match_array ["created_by_id", "created_on", "auditable_id", "auditable_type"] }
        it { expect(subject.created_by).to eq audit.user }
        it { expect(subject.created_on).to eq audit.created_at }
      end

      context 'when audit action is "update"' do
        let(:audit) { auditable.audits.second }
        before(:each) do
          expect(auditable.update(display_name: 'foo')).to be_truthy
          expect(audit.action).to eq 'update'
          expect(audit.user).not_to be_nil
          expect(audit.created_at).not_to be_nil
          expect{ call_method }.not_to raise_error
        end
        it { expect(subject.changed).to match_array ["last_updated_by_id", "last_updated_on", "auditable_id", "auditable_type"] }
        it { expect(subject.last_updated_by).to eq audit.user }
        it { expect(subject.last_updated_on).to eq audit.created_at }
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
