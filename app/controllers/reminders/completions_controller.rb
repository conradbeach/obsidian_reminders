class Reminders::CompletionsController < ApplicationController
  allow_token_authentication only: :create

  def create
    Current.user.reminders.find(params.expect(:reminder_id)).complete

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end

  # Undoes marking the reminder done, which is only possible for a few seconds afterwards.
  def destroy
    reminder = Current.user.reminders_including_completed.find(params.expect(:reminder_id))
    head reminder.undo_completion ? :no_content : :unprocessable_content
  end
end
