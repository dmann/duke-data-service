require 'rails_helper'

describe FolderPolicy do
  include_context 'policy declarations'

  let(:auth_role) { FactoryBot.create(:auth_role) }
  let(:project_permission) { FactoryBot.create(:project_permission, auth_role: auth_role) }
  let(:folder) { FactoryBot.create(:folder, project: project_permission.project) }
  let(:other_folder) { FactoryBot.create(:folder) }

  it_behaves_like 'system_permission can access', :folder
  it_behaves_like 'system_permission can access', :other_folder

  it_behaves_like 'a user with project_permission', :create_file, allows: [:create?, :update?, :move?, :restore?, :rename?], on: :folder
  it_behaves_like 'a user with project_permission', :view_project, allows: [:scope, :index?, :show?], denies: [:move?, :restore?, :rename?], on: :folder
  it_behaves_like 'a user with project_permission', :delete_file, allows: [:destroy?], denies: [:move?, :restore?, :rename?], on: :folder

  it_behaves_like 'a user with project_permission', :create_file, allows: [], denies: [:move?, :restore?, :rename?], on: :other_folder
  it_behaves_like 'a user with project_permission', :view_project, allows: [], denies: [:move?, :restore?, :rename?], on: :other_folder
  it_behaves_like 'a user with project_permission', :delete_file, allows: [], denies: [:move?, :restore?, :rename?], on: :other_folder

  it_behaves_like 'a user without project_permission', [:create_file, :view_project, :update_file, :delete_file], denies: [:scope, :index?, :show?, :create?, :update?, :destroy?, :move?, :restore?, :rename?], on: :folder
  it_behaves_like 'a user without project_permission', [:create_file, :view_project, :update_file, :delete_file], denies: [:scope, :index?, :show?, :create?, :update?, :destroy?, :move?, :restore?, :rename?], on: :other_folder

  context 'when user does not have project_permission' do
    let(:user) { FactoryBot.create(:user) }

    describe '.scope' do
      it { expect(resolved_scope).not_to include(folder) }
      it { expect(resolved_scope).not_to include(other_folder) }
    end
    permissions :index?, :show?, :create?, :move?, :restore?, :rename?, :update?, :destroy? do
      it { is_expected.not_to permit(user, folder) }
      it { is_expected.not_to permit(user, other_folder) }
    end
  end
end
