class Current < ActiveSupport::CurrentAttributes
  # A browser signs in with a session; the API's clients authenticate as a user with their token.
  attribute :session, :user

  def session=(session)
    super
    self.user = session&.user
  end
end
