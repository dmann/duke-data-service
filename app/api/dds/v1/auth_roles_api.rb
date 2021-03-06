module DDS
  module V1
    class AuthRolesAPI < Grape::API
      namespace :auth_roles do
        desc 'List authorization roles for a context' do
          detail 'Lists authorization roles for a given context.'
          named 'list authorization roles'
          failure [
            {code: 200, message: 'Success'},
            {code: 401, message: 'Unauthorized'},
            {code: 404, message: 'Unsupported Context'}
          ]
        end
        params do
          optional :context, values: ['project','system'], type: String, desc: "Role Context, must be one of system, project"
        end
        rescue_from Grape::Exceptions::ValidationErrors do |e|
          error_json = {
            "error" => "404",
            "code" => "not_provided",
            "reason" => "Unknown Context",
            "suggestion" => "Context should be either project or system",
          }
          error!(error_json, 404)
        end
        get '/', adapter: :json, root: 'results' do
          authenticate!
          role_params = declared(params, include_missing: false)
          auth_roles = role_params[:context] ?
            AuthRole.with_context(role_params[:context]) :
            AuthRole.all
          auth_roles
        end

        desc 'View authorization role details' do
          detail 'View authorization role details.'
          named 'view authorization role'
          failure [
            {code: 200, message: 'Success'},
            {code: 401, message: 'Unauthorized'},
            {code: 404, message: 'Unkown AuthRole'}
          ]
        end
        get '/:id', root: false do
          authenticate!
          AuthRole.find(params[:id])
        end
      end
    end
  end
end
