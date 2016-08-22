require 'rails_helper'

RSpec.describe Tag, type: :model do
  let(:project) { FactoryGirl.create(:project) }
  let!(:existing_tag_for_uniqueness_validation) { FactoryGirl.create(:tag, :skip_validation, taggable: project) }
  subject { FactoryGirl.create(:tag) }
  let(:taggable_classes) {[
    DataFile
  ]}
  let(:file) { FactoryGirl.create(:data_file) }
  let(:tag) { FactoryGirl.create(:tag) }

  it_behaves_like 'an audited model'

  describe 'associations' do
    it { is_expected.to belong_to(:taggable) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:taggable) }
    it 'restrict taggable_type to taggable_classes' do
      is_expected.to allow_value(file).for(:taggable)
      is_expected.not_to allow_value(tag).for(:taggable)
    end
    it { is_expected.to validate_uniqueness_of(:label).scoped_to(:taggable_id, :taggable_type).case_insensitive }
  end

  describe '#project_permissions' do
    it { is_expected.to respond_to(:project_permissions) }
    it { expect(subject.project_permissions).to eq(subject.taggable.project_permissions) }
  end

  describe '::taggable_classes' do
    it { expect(described_class).to respond_to(:taggable_classes) }
    it { expect(described_class.taggable_classes).to match_array(taggable_classes)}
  end

  describe '::label_like' do
    it { expect(described_class).to respond_to(:label_like).with(1).argument }
    it { expect(described_class.label_like('label_to_find')).to be_a ActiveRecord::Relation }
  end

  describe '::label_count' do
    it { expect(described_class).to respond_to(:label_count) }
    it { expect(described_class.label_count).to be_a Array }
    context 'with tags' do
      let(:tag_label) { TagLabel.new(label: 'Foo', count: 2) }
      before { FactoryGirl.create_list(:tag, 2, label: 'Foo') }
      it { expect(described_class.label_count).to include(tag_label) }
    end
  end
end
