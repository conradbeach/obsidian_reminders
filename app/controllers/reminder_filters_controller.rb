class ReminderFiltersController < ApplicationController
  def update
    Current.user.update!(show_today_only: params.expect(:show_today_only))
    redirect_to root_path
  end
end
