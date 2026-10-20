# Reads Rails credentials for Kamal's ERB-rendered config without booting Rails.
require "active_support/encrypted_configuration"

KAMAL_CREDENTIALS = ActiveSupport::EncryptedConfiguration.new(
  config_path: "config/credentials.yml.enc",
  key_path: "config/master.key",
  env_key: "RAILS_MASTER_KEY",
  raise_if_missing_key: true,
)
