# check=skip=CopyIgnoredFile
FROM ghcr.io/basecamp/fizzy:main

LABEL org.opencontainers.image.title="fizzy-time_tracking"
LABEL org.opencontainers.image.description="Fizzy with time tracking: per-card time logging for hours and minutes"
LABEL org.opencontainers.image.source="https://github.com/richardkmichael/fizzy-time_tracking"
LABEL org.opencontainers.image.licenses="O'Saasy"

USER root
COPY --chown=rails:rails . /engine

# Add the time tracking engine to Fizzy's bundle.
#   BUNDLE_DEPLOYMENT="" — temporarily lifts Bundler's strict deployment mode
#     so a new gem can be added (deployment mode forbids Gemfile changes).
#   bundle add runs bundle install, which is conservative: it only resolves the
#     new gem while keeping all existing Fizzy dependencies at locked versions.
RUN cd /rails && \
    BUNDLE_DEPLOYMENT="" bundle add fizzy-time_tracking --path /engine && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails g fizzy_time_tracking:install && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    chown -R rails:rails /rails/public/assets /rails/db/migrate /rails/tmp/cache

USER rails:rails
