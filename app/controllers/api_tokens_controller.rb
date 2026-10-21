class ApiTokensController < ApplicationController
  def create
    Current.user.regenerate_api_token
    redirect_to settings_path(anchor: "api-token"), notice: "Your API token is replaced."
  end
end
