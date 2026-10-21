class RemindersController < ApplicationController
  def index
    load_reminders
    @addition = Reminder::Addition.new
  end

  def create
    @addition = Reminder::Addition.new(user: Current.user, **params.expect(reminder_addition: [:text, :time]))

    if @addition.save
      redirect_to root_path
    else
      load_reminders
      render :index, status: :unprocessable_content
    end
  end

  private

  def load_reminders
    user = Current.user
    current = user.reminders.scheduled_since(user.overdue_since)
    current = current.through_today if user.show_today_only?
    @current_by_day = current.group_by { it.remind_at.to_date }
    # Open until they're checked off or deleted, however old.
    @overdue = user.reminders.scheduled_before(user.overdue_since)
    @unscheduled = user.reminders.unscheduled
  end
end
