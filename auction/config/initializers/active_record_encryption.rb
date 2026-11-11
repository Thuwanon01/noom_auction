# Keys for Active Record Encryption (used for users.national_id).
#
# Production: set them in credentials (`bin/rails db:encryption:init` prints a block
# to paste under `active_record_encryption:`) or in the AR_ENCRYPTION_* env vars.
# Development and test fall back to fixed, non-secret keys so the app runs
# without config/master.key.
Rails.application.configure do
  creds = Rails.application.credentials.active_record_encryption || {}
  dev_fallback = !Rails.env.production?

  {
    primary_key: [ "AR_ENCRYPTION_PRIMARY_KEY", "dev-primary-key-not-secret-0000000" ],
    deterministic_key: [ "AR_ENCRYPTION_DETERMINISTIC_KEY", "dev-deterministic-key-not-secret-0" ],
    key_derivation_salt: [ "AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev-key-derivation-salt-not-secret" ]
  }.each do |name, (env_var, dev_value)|
    value = creds[name].presence || ENV[env_var].presence || (dev_value if dev_fallback)
    config.active_record.encryption.public_send("#{name}=", value) if value
  end
end
