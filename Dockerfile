# check=skip=CopyIgnoredFile
ARG FIZZY_IMAGE_TAG=main

# Build stage: has git for bundler (Fizzy's Gemfile includes git-sourced gems).
# Adds the engine gem, runs the install generator, and precompiles assets.
# git is not carried into the final image.
FROM ghcr.io/basecamp/fizzy:${FIZZY_IMAGE_TAG} AS build

USER root
COPY --chown=rails:rails . /engine

RUN apt-get update && apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    cd /rails && \
    BUNDLE_DEPLOYMENT="" bundle add fizzy-time_tracking --path /engine && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails g fizzy_time_tracking:install && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    chown -R rails:rails /usr/local/bundle /rails /engine

# Final stage: clean Fizzy image with only the build artifacts copied in.
FROM ghcr.io/basecamp/fizzy:${FIZZY_IMAGE_TAG}

LABEL org.opencontainers.image.title="fizzy-time_tracking"
LABEL org.opencontainers.image.description="Fizzy with time tracking: per-card time logging for hours and minutes"
LABEL org.opencontainers.image.source="https://github.com/richardkmichael/fizzy-time_tracking"
LABEL org.opencontainers.image.licenses="O'Saasy"

USER root

# Engine source (path gem — needed at runtime)
COPY --chown=rails:rails --from=build /engine /engine

# Updated gem bundle and manifest (bundle add modifies both)
COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails/Gemfile /rails/Gemfile.lock /rails/

# Host app files modified by the install generator and asset pipeline
COPY --chown=rails:rails --from=build /rails/app /rails/app
COPY --chown=rails:rails --from=build /rails/db/migrate /rails/db/migrate
COPY --chown=rails:rails --from=build /rails/public/assets /rails/public/assets

USER rails:rails
