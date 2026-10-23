class RemindersController < ApplicationController
  allow_token_authentication only: [:index, :create]

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
    @query = params[:q].presence
    reminders = Current.user.reminders.matching(@query)
    @current_by_day = current(reminders).group_by { it.remind_at.to_date }
    # Open until they're checked off or deleted, however old.
    @overdue = reminders.scheduled_before(Current.user.overdue_since)
    @unscheduled = reminders.unscheduled
  end

  # Those not yet overdue. A search looks through all of them, even when the user shows only today.
  def current(reminders)
    current = reminders.scheduled_since(Current.user.overdue_since)
    Current.user.show_today_only? && !@query ? current.through_today : current
  end
end
