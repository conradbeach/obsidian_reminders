class RemindersController < ApplicationController
  def index
    respond_to do |format|
      format.html do
        load_reminders
        @addition = Reminder::Addition.new
      end
      format.json do
        render json: { overdue_after_hours: Current.user.overdue_after_hours,
                       reminders: Current.user.reminders.scheduled }
      end
    end
  end

  def create
    @addition = Reminder::Addition.new(user: Current.user, **params.expect(reminder_addition: [:text, :time]))
    reminder = @addition.save
    return render_invalid_addition unless reminder

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { render json: reminder, status: :created }
    end
  end

  private

  def render_invalid_addition
    respond_to do |format|
      format.html do
        load_reminders
        render :index, status: :unprocessable_content
      end
      format.json { render json: { errors: @addition.errors.full_messages }, status: :unprocessable_content }
    end
  end

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
