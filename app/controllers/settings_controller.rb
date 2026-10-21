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
    params.expect(user: [:note_folders, :overdue_after_hours, :reminders_note]).tap do |settings|
      settings[:note_folders] = settings[:note_folders].split(/\R/) if settings.key?(:note_folders)
    end
  end
end
