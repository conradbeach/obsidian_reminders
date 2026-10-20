class RemindersController < ApplicationController
  def index
    @upcoming_by_day = Current.user.reminders.upcoming.group_by { it.remind_at.to_date }
    @unscheduled = Current.user.reminders.unscheduled
  end
end
