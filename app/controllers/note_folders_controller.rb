class NoteFoldersController < ApplicationController
  def update
    Current.user.update!(note_folders: params.expect(:note_folders).split(/\R/))
    redirect_to settings_path, notice: "Your folders are saved."
  end
end
