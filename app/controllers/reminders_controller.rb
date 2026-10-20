class RemindersController < ApplicationController
  def index
    @upcoming = Reminder.upcoming
    @unscheduled = Reminder.unscheduled
  end
end
