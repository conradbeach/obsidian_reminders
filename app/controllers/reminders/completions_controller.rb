class Reminders::CompletionsController < ApplicationController
  allow_token_authentication only: :create

  def create
    Current.user.reminders.find(params.expect(:reminder_id)).complete

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end
end
