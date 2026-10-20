class RemindersController < ApplicationController
  def index
    @today_only = params[:show] == "today"
    upcoming = Current.user.reminders.upcoming
    upcoming = upcoming.today if @today_only
    @upcoming_by_day = upcoming.group_by { it.remind_at.to_date }
    @unscheduled = Current.user.reminders.unscheduled
  end
end
