# frozen_string_literal: true

# In CI, set GOOGLE_SITE_VERIFICATION to the "content" value from Google Search Console's HTML tag
# verification method (repository secret). This avoids committing the token to git.
Jekyll::Hooks.register :site, :after_init do |site|
  token = ENV.fetch("GOOGLE_SITE_VERIFICATION", "").strip
  next if token.empty?

  site.config["google_site_verification"] = token
  site.config["enable_google_verification"] = true
end
