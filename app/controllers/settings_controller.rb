class SettingsController < ApplicationController
  def show; end

  def update
    if Current.user.update(settings_params)
      redirect_to settings_path, notice: "Your settings are saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def settings_params
    params.expect(user: [:note_folders, :ignored_folders, :overdue_after_hours, :reminders_note]).tap do |settings|
      [:note_folders, :ignored_folders].each { settings[it] = settings[it].split(/\R/) if settings.key?(it) }
    end
  end
end
