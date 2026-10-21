class Reminders::CompletionsController < ApplicationController
  def create
    Current.user.reminders.find(params.expect(:reminder_id)).complete
    redirect_to root_path
  end
end
