require 'rails_helper'

RSpec.describe GeneratedByActivityProvRelation, type: :model do
  subject do |example|
    if example.metadata[:subject_created]
      FactoryGirl.create(:generated_by_activity_prov_relation)
    else
      FactoryGirl.build_stubbed(:generated_by_activity_prov_relation)
    end
  end
  let(:resource_serializer) { GeneratedByActivityProvRelationSerializer }
  let(:expected_relationship_type) { 'was-generated-by' }

  it_behaves_like 'a ProvRelation' do
    let(:expected_kind) { 'dds-relation-was-generated-by' }
    let(:serialized_kind) { true }
    let(:kinded_class) { GeneratedByActivityProvRelation }
  end

  describe 'validations' do
    it { is_expected.to allow_value('FileVersion').for(:relatable_from_type) }
    it { is_expected.not_to allow_value('User').for(:relatable_from_type) }
    it { is_expected.not_to allow_value('SoftwareAgent').for(:relatable_from_type) }
    it { is_expected.not_to allow_value('Project').for(:relatable_from_type) }
    it { is_expected.not_to allow_value('DataFile').for(:relatable_from_type) }
    it { is_expected.not_to allow_value('Container').for(:relatable_from_type) }

    it { is_expected.to allow_value('Activity').for(:relatable_to_type) }
    it { is_expected.not_to allow_value('User').for(:relatable_to_type) }
    it { is_expected.not_to allow_value('Project').for(:relatable_to_type) }
    it { is_expected.not_to allow_value('FileVersion').for(:relatable_to_type) }
    it { is_expected.not_to allow_value('SoftwareAgent').for(:relatable_to_type) }
    it 'validates uniqueness', :subject_created do
      is_expected.to validate_uniqueness_of(:relatable_from_id).scoped_to(:relatable_to_id).case_insensitive
    end

    context 'already used by activity' do
      let(:used_and_generated_by) { FactoryGirl.create(:activity) }
      let(:used_and_generated) { FactoryGirl.create(:file_version) }
      subject { FactoryGirl.build(:generated_by_activity_prov_relation,
        relatable_to: used_and_generated_by,
        relatable_from: used_and_generated)
      }
      context 'not deleted' do
        let(:already_used) { FactoryGirl.build(:used_prov_relation,
          relatable_from: used_and_generated_by,
          relatable_to: used_and_generated
          )
        }
        it {
          is_expected.to be_valid
          already_used.save
          is_expected.not_to be_valid
        }
      end

      context 'deleted' do
        let(:already_used) { FactoryGirl.build(:used_prov_relation,
          relatable_from: used_and_generated_by,
          relatable_to: used_and_generated,
          is_deleted: true
          )
        }
        it {
          is_expected.to be_valid
          already_used.save
          is_expected.to be_valid
        }
      end
    end
  end
end
