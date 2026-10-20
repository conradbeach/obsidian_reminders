class NoteFoldersController < ApplicationController
  def edit; end

  def update
    Current.user.update!(note_folders: params.expect(:note_folders).split(/\R/))
    redirect_to root_path, notice: "Your folders are saved."
  end
end
