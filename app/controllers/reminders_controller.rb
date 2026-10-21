class RemindersController < ApplicationController
  def index
    user = Current.user
    current = user.reminders.scheduled_since(user.overdue_since)
    current = current.through_today if user.show_today_only?
    @current_by_day = current.group_by { it.remind_at.to_date }
    # Open until they're checked off or deleted, however old.
    @overdue = user.reminders.scheduled_before(user.overdue_since)
    @unscheduled = user.reminders.unscheduled
  end
end
