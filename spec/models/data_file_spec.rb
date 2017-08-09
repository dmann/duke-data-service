require 'rails_helper'

RSpec.describe DataFile, type: :model do
  subject do |example|
    if example.metadata[:subject_created]
      FactoryGirl.create(:data_file, :with_parent)
    else
      child_file
    end
  end
  let(:root_file) { FactoryGirl.build_stubbed(:data_file, :root) }
  let(:child_file) { FactoryGirl.build_stubbed(:data_file, :with_parent) }
  let(:invalid_file) { FactoryGirl.build_stubbed(:data_file, :invalid) }
  let(:deleted_file) { FactoryGirl.build_stubbed(:data_file, :deleted) }
  let(:project) { subject.project }
  let(:other_project) { FactoryGirl.create(:project) }
  let(:other_folder) { FactoryGirl.create(:folder, project: other_project) }
  let(:uri_encoded_name) { URI.encode(subject.name) }

  it_behaves_like 'an audited model'
  it_behaves_like 'a kind' do
    let(:expected_kind) { 'dds-file' }
    let(:kinded_class) { DataFile }
    let(:serialized_kind) { true }
  end
  it_behaves_like 'a logically deleted model'

  it_behaves_like 'a job_transactionable model'

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:parent) }
    it { is_expected.to have_many(:project_permissions).through(:project) }
    it { is_expected.to have_many(:file_versions).order('version_number ASC').autosave(true) }
    it { is_expected.to have_many(:tags) }
    it { is_expected.to have_many(:meta_templates) }
  end

  describe 'validations' do
    let(:completed_upload) { FactoryGirl.build_stubbed(:upload, :completed, :with_fingerprint, project: subject.project) }
    let(:incomplete_upload) { FactoryGirl.build_stubbed(:upload, project: subject.project) }
    let(:upload_with_error) { FactoryGirl.build_stubbed(:upload, :with_error, project: subject.project) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:upload) }

    it 'should not allow project_id to be changed', :subject_created do
      should allow_value(project).for(:project)
      expect(subject).to be_valid
      should allow_value(project.id).for(:project_id)
      should_not allow_value(other_project.id).for(:project_id)
      should allow_value(project.id).for(:project_id)
      expect(subject).to be_valid
      should allow_value(other_project).for(:project)
      expect(subject).not_to be_valid
    end

    it 'should require upload has no error' do
      should allow_value(completed_upload).for(:upload)
      should_not allow_value(upload_with_error).for(:upload)
      should_not allow_value(upload_with_error).for(:upload)
      expect(subject.valid?).to be_falsey
      expect(subject.errors.keys).to include(:upload)
      expect(subject.errors[:upload]).to include('cannot have an error')
    end

    it 'should require a completed upload' do
      should allow_value(completed_upload).for(:upload)
      should_not allow_value(incomplete_upload).for(:upload)
      expect(subject.valid?).to be_falsey
      expect(subject.errors.keys).to include(:upload)
      expect(subject.errors[:upload]).to include('must be completed successfully')
    end

    it 'should allow is_deleted to be set' do
      should allow_value(true).for(:is_deleted)
      should allow_value(false).for(:is_deleted)
    end

    context 'when .is_deleted=true' do
      subject { deleted_file }
      it { is_expected.not_to validate_presence_of(:name) }
      it { is_expected.not_to validate_presence_of(:project_id) }
      it { is_expected.not_to validate_presence_of(:upload) }
      it { expect(deleted_file.file_versions).to all( be_is_deleted ) }
    end
  end

  describe '.parent=', :subject_created do
    it 'should set project to parent.project' do
      expect(subject.parent).not_to eq other_folder
      expect(subject.project).not_to eq other_folder.project
      expect(subject.project_id).not_to eq other_folder.project_id
      should allow_value(other_folder).for(:parent)
      expect(subject.parent).to eq other_folder
      expect(subject.project).to eq other_folder.project
      expect(subject.project_id).to eq other_folder.project_id
    end
  end

  describe '.parent_id=', :subject_created do
    it 'should set project to parent.project' do
      expect(subject.parent).not_to eq other_folder
      expect(subject.project).not_to eq other_folder.project
      expect(subject.project_id).not_to eq other_folder.project_id
      should allow_value(other_folder.id).for(:parent_id)
      expect(subject.parent).to eq other_folder
      expect(subject.project).to eq other_folder.project
      expect(subject.project_id).to eq other_folder.project_id
    end
  end

  describe 'instance methods' do
    it { should delegate_method(:http_verb).to(:upload) }
    it { should delegate_method(:host).to(:upload).as(:url_root) }
    it { should delegate_method(:url).to(:upload).as(:temporary_url) }

    describe '#url', :subject_created do
      it { expect(subject.url).to include uri_encoded_name }
    end

    describe '#upload' do
      subject { FactoryGirl.build(:data_file, without_upload: true) }
      let(:completed_upload) { FactoryGirl.create(:upload, :completed, :with_fingerprint, project: subject.project) }
      let(:different_upload) { FactoryGirl.build_stubbed(:upload, :completed, :with_fingerprint, project: subject.project) }

      context 'before save' do
        it { expect(subject.upload).to be_nil }
        it { expect(subject.file_versions).to be_empty }

        context 'set #upload to nil' do
          before(:each) do
            expect {
              subject.upload = nil
            }.to change { subject.file_versions.length }.by(1)
          end

          it { expect(subject.upload).to be_nil }
          it { expect(subject.current_file_version.upload).to be_nil }
        end

        context 'set #upload to an upload' do
          before(:each) do
            expect {
              subject.upload = completed_upload
            }.to change { subject.file_versions.length }.by(1)
          end

          it { expect(subject.upload).to eq completed_upload }
          it { expect(subject.current_file_version.upload).to eq completed_upload }
        end
      end

      context 'after save' do
        before(:each) do
          subject.upload = completed_upload
          expect(subject.save).to be_truthy
        end
        it { expect(subject.upload).to eq completed_upload }
        it { expect(subject.file_versions.length).to eq(1) }
        it { expect(subject.current_file_version.upload).to eq completed_upload }

        context 'set #upload to nil' do
          before(:each) do
            expect {
              subject.upload = nil
            }.to change { subject.file_versions.length }.by(1)
          end

          it { expect(subject.upload).to be_nil }
          it { expect(subject.current_file_version.upload).to be_nil }
        end

        context 'set #upload to a different upload' do
          before(:each) do
            expect {
              subject.upload = different_upload
            }.to change { subject.file_versions.length }.by(1)
          end

          it { expect(subject.upload).to eq different_upload }
          it { expect(subject.current_file_version.upload).to eq different_upload }
        end

        context 'set #upload to the same upload' do
          before(:each) do
            expect {
              subject.upload = completed_upload
            }.not_to change { subject.file_versions.length }
          end

          it { expect(subject.upload).to eq completed_upload }
          it { expect(subject.current_file_version.upload).to eq completed_upload }
        end
      end
    end

    describe 'ancestors' do
      it 'should respond with an Array' do
        is_expected.to respond_to(:ancestors)
        expect(subject.ancestors).to be_a Array
      end

      context 'with a parent folder' do
        subject { child_file }
        it 'should return the project and parent' do
          expect(subject.project).to be
          expect(subject.parent).to be
          expect(subject.ancestors).to eq [subject.project, subject.parent]
        end
      end

      context 'without a parent' do
        subject { root_file }
        it 'should return the project' do
          expect(subject.project).to be
          expect(subject.ancestors).to eq [subject.project]
        end
      end
    end

    describe '#current_file_version' do
      it { is_expected.to respond_to(:current_file_version) }
      it 'persists the current file_version', :subject_created do
        expect(subject.current_file_version).to be_persisted
      end
      it { expect(subject.current_file_version).to eq subject.current_file_version }

      context 'with unsaved file_version' do
        before { subject.build_file_version }
        it { expect(subject.current_file_version).not_to be_persisted }
        it { expect(subject.current_file_version).to eq subject.current_file_version }
      end

      context 'with multiple file_versions', :subject_created do
        let(:last_file_version) { FactoryGirl.create(:file_version, data_file: subject) }
        before do
          expect(last_file_version).to be_persisted
          subject.reload
        end
        it { expect(subject.current_file_version).to eq last_file_version }
      end
    end

    describe '#build_file_version' do
      it { is_expected.to respond_to(:build_file_version) }
      it { expect(subject.build_file_version).to be_a FileVersion }
      it 'builds a file_version' do
        expect {
          subject.build_file_version
        }.to change{subject.file_versions.length}.by(1)
      end
    end

    describe '#set_current_file_version_attributes' do
      let(:latest_version) { subject.current_file_version }
      it { is_expected.to respond_to(:set_current_file_version_attributes) }
      context 'when persisted', :subject_created do
        it { expect(subject.set_current_file_version_attributes).to be_a FileVersion }
        it { expect(subject.set_current_file_version_attributes).to eq latest_version }
        context 'with persisted file_version' do
          it { expect(latest_version).to be_persisted }
          it { expect(subject.set_current_file_version_attributes.changed?).to be_falsey }
        end
      end
      context 'with new file_version' do
        before { subject.build_file_version }
        it { expect(subject.set_current_file_version_attributes.changed?).to be_truthy }
        it { expect(subject.set_current_file_version_attributes.upload).to eq subject.upload }
        it { expect(subject.set_current_file_version_attributes.label).to eq subject.label }
      end
    end
  end

  describe 'callbacks' do
    it { is_expected.to callback(:set_project_to_parent_project).after(:set_parent_attribute) }
    it { is_expected.to callback(:set_current_file_version_attributes).before(:save) }
  end

  describe '#creator' do
    let(:creator) { FactoryGirl.create(:user) }
    it { is_expected.to respond_to :creator }

    context 'with nil current_file_version' do
      subject {
        df = FactoryGirl.build_stubbed(:data_file)
        df.file_versions.destroy_all
        df
      }
      it {
        expect(subject.current_file_version).to be_nil
        expect(subject.creator).to be_nil
      }
    end

    context 'with nil current_file_version create audit' do
      subject {
        FactoryGirl.create(:data_file)
      }

      around(:each) do |example|
          FileVersion.auditing_enabled = false
          example.run
          FileVersion.auditing_enabled = true
      end

      it {
        expect(subject.current_file_version).not_to be_nil
        expect(subject.current_file_version.audits.find_by(action: 'create')).to be_nil
        expect(subject.creator).to be_nil
      }
    end

    context 'with current_file_version and create audit' do
      subject {
        Audited.audit_class.as_user(creator) do
          FactoryGirl.create(:data_file)
        end
      }
      it {
        expect(subject.current_file_version).not_to be_nil
        expect(subject.current_file_version.audits.find_by(action: 'create')).not_to be_nil
        expect(subject.creator.id).to eq(subject.current_file_version.audits.find_by(action: 'create').user.id)
      }
    end
  end

  describe 'elasticsearch' do
    let(:search_serializer) { Search::DataFileSerializer }
    let(:property_mappings) {{
      kind: {type: "string", index: "not_analyzed"},
      id: {type: "string", index: "not_analyzed"},
      label: {type: "string"},
      parent: {type: "object"},
      name: {type: "string"},
      audit: {type: "object"},
      is_deleted: {type: "boolean"},
      created_at: {type: "date"},
      updated_at: {type: "date"},
      tags: {type: "object"},
      current_version: {type: "object"},
      project: {type: "object"},
      ancestors: {type: "object"},
      creator: {type: "object"}
    }}
    include_context 'with job runner', ElasticsearchIndexJob

    it_behaves_like 'an Elasticsearch::Model' do
      context 'when ElasticsearchIndexJob::perform_later raises an error' do
        context 'with new data_file' do
          subject { FactoryGirl.build(:data_file, :root) }
          before(:each) do
            expect(ElasticsearchIndexJob).to receive(:perform_later).with(anything, anything).and_raise("boom!")
          end
          it { expect{
            expect{subject.save}.to raise_error("boom!")
          }.not_to change{described_class.count} }
        end
        context 'with existing data_file' do
          subject { FactoryGirl.create(:data_file, :root) }
          before(:each) do
            is_expected.to be_persisted
            subject.name += 'x'
            expect(ElasticsearchIndexJob).to receive(:perform_later).with(anything, anything, update: true).and_raise("boom!")
          end
          it { expect{
            expect{subject.save}.to raise_error("boom!")
          }.not_to change{described_class.find(subject.id).name} }
        end
      end
    end
    it_behaves_like 'an Elasticsearch index mapping model' do
      it {
        #tags
        expect(subject[:data_file][:properties][:tags]).to have_key :properties
        expect(subject[:data_file][:properties][:tags][:properties]).to have_key :label
        expect(subject[:data_file][:properties][:tags][:properties][:label][:type]).to eq "string"
        expect(subject[:data_file][:properties][:tags][:properties][:label]).to have_key :fields
        expect(subject[:data_file][:properties][:tags][:properties][:label][:fields]).to have_key :raw
        expect(subject[:data_file][:properties][:tags][:properties][:label][:fields][:raw][:type]).to eq "string"
        expect(subject[:data_file][:properties][:tags][:properties][:label][:fields][:raw][:index]).to eq "not_analyzed"

        #project
        expect(subject[:data_file][:properties][:project]).to have_key :properties
        expect(subject[:data_file][:properties][:project][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:project][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:project][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:project][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:project][:properties][:name][:type]).to eq "string"

        #parent
        expect(subject[:data_file][:properties][:parent]).to have_key :properties
        expect(subject[:data_file][:properties][:parent][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:parent][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:parent][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:parent][:properties]).to have_key :kind
        expect(subject[:data_file][:properties][:parent][:properties][:kind][:type]).to eq "string"
        expect(subject[:data_file][:properties][:parent][:properties][:kind][:index]).to eq "not_analyzed"

        #creator
        expect(subject[:data_file][:properties][:creator]).to have_key :properties
        expect(subject[:data_file][:properties][:creator][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:creator][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:creator][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:creator][:properties]).to have_key :username
        expect(subject[:data_file][:properties][:creator][:properties][:username][:type]).to eq "string"
        expect(subject[:data_file][:properties][:creator][:properties]).to have_key :email
        expect(subject[:data_file][:properties][:creator][:properties][:email][:type]).to eq "string"
        expect(subject[:data_file][:properties][:creator][:properties]).to have_key :first_name
        expect(subject[:data_file][:properties][:creator][:properties][:first_name][:type]).to eq "string"
        expect(subject[:data_file][:properties][:creator][:properties]).to have_key :last_name
        expect(subject[:data_file][:properties][:creator][:properties][:last_name][:type]).to eq "string"

        #audit
        expect(subject[:data_file][:properties][:audit]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :created_on
        expect(subject[:data_file][:properties][:audit][:properties][:created_on][:type]).to eq "date"
        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :created_by
        expect(subject[:data_file][:properties][:audit][:properties][:created_by]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties]).to have_key :username
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:username][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties]).to have_key :full_name
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:full_name][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties]).to have_key :agent
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:audit][:properties][:created_by][:properties][:agent][:properties][:name][:type]).to eq "string"

        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :last_updated_on
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_on][:type]).to eq "date"
        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :last_updated_by
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties]).to have_key :username
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:username][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties]).to have_key :full_name
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:full_name][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties]).to have_key :agent
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:audit][:properties][:last_updated_by][:properties][:agent][:properties][:name][:type]).to eq "string"

        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :deleted_on
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_on][:type]).to eq "date"
        expect(subject[:data_file][:properties][:audit][:properties]).to have_key :deleted_by
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties]).to have_key :username
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:username][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties]).to have_key :full_name
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:full_name][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties]).to have_key :agent
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent]).to have_key :properties
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:audit][:properties][:deleted_by][:properties][:agent][:properties][:name][:type]).to eq "string"

        #current_version
        expect(subject[:data_file][:properties][:current_version]).to have_key :properties
        expect(subject[:data_file][:properties][:current_version][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:current_version][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:current_version][:properties]).to have_key :version
        expect(subject[:data_file][:properties][:current_version][:properties][:version][:type]).to eq "integer"
        expect(subject[:data_file][:properties][:current_version][:properties]).to have_key :label
        expect(subject[:data_file][:properties][:current_version][:properties][:label][:type]).to eq "string"

        expect(subject[:data_file][:properties][:current_version][:properties]).to have_key :upload
        expect(subject[:data_file][:properties][:current_version][:properties][:upload]).to have_key :properties
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties]).to have_key :size
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:size][:type]).to eq "long"

        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties]).to have_key :storage_provider
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider]).to have_key :properties
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties][:name][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties]).to have_key :description
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:storage_provider][:properties][:description][:type]).to eq "string"

        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties]).to have_key :hashes
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes]).to have_key :properties
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties]).to have_key :algorithm
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties][:algorithm][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties][:algorithm][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties]).to have_key :value
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties][:value][:type]).to eq "string"
        expect(subject[:data_file][:properties][:current_version][:properties][:upload][:properties][:hashes][:properties][:value][:index]).to eq "not_analyzed"

        #ancestors
        expect(subject[:data_file][:properties][:ancestors]).to have_key :properties
        expect(subject[:data_file][:properties][:ancestors][:properties]).to have_key :kind
        expect(subject[:data_file][:properties][:ancestors][:properties][:kind][:type]).to eq "string"
        expect(subject[:data_file][:properties][:ancestors][:properties][:kind][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:ancestors][:properties]).to have_key :id
        expect(subject[:data_file][:properties][:ancestors][:properties][:id][:type]).to eq "string"
        expect(subject[:data_file][:properties][:ancestors][:properties][:id][:index]).to eq "not_analyzed"
        expect(subject[:data_file][:properties][:ancestors][:properties]).to have_key :name
        expect(subject[:data_file][:properties][:ancestors][:properties][:name][:type]).to eq "string"
      }
    end
  end
end
