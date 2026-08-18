# Fizzy is the host app for this engine — an external Rails app with its own
# Gemfile, cloned into test/fizzy/ by `rake setup`.
#
# Standard engines keep a test/dummy app *inside* the engine's bundle, so
# APP_RAKEFILE + rails/tasks/engine.rake just works. Here, Fizzy has a
# separate bundle. We bridge that gap by pointing BUNDLE_GEMFILE at Fizzy's
# Gemfile before Bundler loads — Fizzy's bundle includes this engine as a
# path gem, so everything resolves. On first clone (before `rake dev:setup`),
# Fizzy isn't present yet; we fall back to the engine's own Gemfile so that
# rake dev:setup can bootstrap.

ENGINE_ROOT = __dir__
FIZZY_PATH  = ENV.fetch("FIZZY_PATH") { File.expand_path("test/fizzy", ENGINE_ROOT) }
# The git ref the host app is cloned at. Defaults to Fizzy's newest release,
# which is what CI builds against, so local runs and CI agree.
def fizzy_ref
  @fizzy_ref ||= ENV.fetch("FIZZY_REF") do
    if (tag = ENV["FIZZY_IMAGE_TAG"])
      # An arbitrary sha- image tag has no matching git tag, so clone main.
      tag.start_with?("sha-") ? "main" : tag
    else
      latest_fizzy_release || "main"
    end
  end
end

# The Docker tag for the Dockerfile's FROM line, derived from the git ref:
# release "fizzy@37d7f5c" corresponds to image "sha-37d7f5c".
def fizzy_image_tag
  @fizzy_image_tag ||= ENV.fetch("FIZZY_IMAGE_TAG") do
    fizzy_ref.start_with?("fizzy@") ? "sha-#{fizzy_ref.delete_prefix("fizzy@")}" : fizzy_ref
  end
end

# Resolved from GitHub Releases rather than Docker tags: Fizzy publishes a
# sha- image on every push to main, but a git tag only for a release.
def latest_fizzy_release
  @latest_fizzy_release ||= begin
    tag = `gh api '/repos/basecamp/fizzy/releases?per_page=100' \
      --jq 'map(select((.tag_name | startswith("fizzy@")) and (.draft == false)))
             | sort_by(.published_at) | last | .tag_name' 2>/dev/null`.strip
    (tag.empty? || tag == "null") ? nil : tag
  rescue
    nil
  end
end

fizzy_gemfile = File.join(FIZZY_PATH, "Gemfile")
ENV["BUNDLE_GEMFILE"] = fizzy_gemfile if File.exist?(fizzy_gemfile)

require "bundler/setup"
require "open3"

task default: :test

if File.directory?(FIZZY_PATH)
  engine_test_dirs = Dir[File.join(ENGINE_ROOT, "test", "*/")]
    .reject { |d| d.end_with?("fizzy/", "fixtures/") }

  desc "Run engine tests via Fizzy host app"
  task :test do
    in_fizzy "bin/rails", "test", *engine_test_dirs
  end

  namespace :test do
    desc "Run Fizzy's own test suite (catches regressions in the host app)"
    task :fizzy do
      in_fizzy "bin/rails", "test"
    end
  end
else
  task :test do
    abort "Fizzy host app not found at #{FIZZY_PATH}. Run `rake dev:setup` first."
  end
end

namespace :dev do
  desc "Start the development server"
  task :server do
    in_fizzy "bin/dev"
  end

  desc "Clone and configure Fizzy host app for running engine tests"
  task :setup do
    clone_fizzy
    add_engine_to_gemfile

    in_fizzy "bundle", "install"
    in_fizzy "bin/rails", "db:prepare"
    in_fizzy "bin/rails", "generate", "fizzy_time_tracking:install"
    in_fizzy "bin/rails", "db:migrate"
  end
end

GHCR_IMAGE      = "ghcr.io/richardkmichael/fizzy-time_tracking:latest"
CONTAINER_NAME  = "fizzy"
DEFAULT_VOLUME  = "fizzy-time_tracking-data"

namespace :dev do
  desc "Test the build with the production Dockerfile"
  task :build do
    Dir.chdir(ENGINE_ROOT) { sh "docker", "build", "--build-arg", "FIZZY_IMAGE_TAG=#{fizzy_image_tag}", "-t", "fizzy-time_tracking", "." }
  end
end

namespace :prod do
  desc "Start the GHCR image (rake prod:start[./data] or rake prod:start[my-volume])"
  task :start, [ :storage ] do |_t, args|
    storage = args.fetch(:storage, DEFAULT_VOLUME)
    volume = if storage.start_with?("/", ".")
      File.expand_path(storage, ENGINE_ROOT)
    else
      storage
    end

    ensure_docker_running

    if container_exists?(CONTAINER_NAME)
      current = container_storage_mount(CONTAINER_NAME)
      if current != volume
        puts
        puts "Container #{CONTAINER_NAME} already exists with different storage:"
        puts "  existing:  #{current}"
        puts "  requested: #{volume}"
        puts

        print "Start container with its existing storage (#{current})? [Y/n] "
        case $stdin.gets.to_s.strip.downcase
        when "", "y", "yes"
          volume = current
          puts "Using existing storage: #{current}"
        else
          abort <<~MSG
            Aborted. To switch storage, remove the container first:
              bundle exec rake prod:stop
              docker rm #{CONTAINER_NAME}
              bundle exec rake prod:start[#{storage}]
          MSG
        end
      end
    end

    unless container_running?(CONTAINER_NAME)
      docker "pull", GHCR_IMAGE

      if container_exists?(CONTAINER_NAME) && container_image_id(CONTAINER_NAME) != image_id(GHCR_IMAGE)
        docker "rm", CONTAINER_NAME
      end

      if container_exists?(CONTAINER_NAME)
        docker "start", CONTAINER_NAME
      else
        start_container(volume)
      end

      docker "image", "prune", "-f"
    end

    puts
    puts "URL:      http://localhost:8080"
    puts "Logs:     docker logs -f #{CONTAINER_NAME}"
    puts "Stop:     rake prod:stop"
    puts "Sign in:  docker exec #{CONTAINER_NAME} bin/rails runner 'puts Identity.find_or_create_by!(email_address: ARGV[0]).magic_links.create!.code' YOUR@EMAIL.COM"
  end

  desc "Stop the running container"
  task :stop do
    docker "stop", CONTAINER_NAME if container_running?(CONTAINER_NAME)
  end

  desc "Remove all fizzy containers and images"
  task :clean do
    ensure_docker_running
    docker "rm", "-f", CONTAINER_NAME rescue nil
    docker "rmi", GHCR_IMAGE rescue nil
    docker "image", "prune", "-f"
    puts "Cleaned up #{CONTAINER_NAME} containers and images."
  end
end

# Signals a release by force-pushing the `latest` git tag to HEAD, which triggers
# the Latest CI workflow to build multi-platform (amd64 + arm64) images and push
# them to GHCR.
#
# Caveat: the git tag moves before CI confirms the build succeeded. If the build
# fails, `latest` points to broken code until a fix is pushed and released.
#
# Future improvement: build on every development push (pushing a :development image
# to GHCR), and make `rake release` retag :development -> :latest in GHCR rather
# than rebuilding. The git tag would only move after a confirmed successful build.
# The tricky part is the scheduled Fizzy-base-update path in latest.yml, which
# needs a full rebuild (not a retag) when Fizzy releases a new version. That
# interaction — our code updates vs. Fizzy base updates as separate release triggers
# — needs careful design before implementing.
desc "Release: push the `latest` git tag to HEAD, triggering CI to build and push the GHCR image"
task :release do
  sh "git", "tag", "-f", "latest", "HEAD"
  sh "git", "push", "origin", "latest", "--force"
end

desc "Remove time tracking data from a Fizzy database (see UNINSTALL.md)"
task :uninstall, [ :storage ] do |_t, args|
  storage = args.fetch(:storage, DEFAULT_VOLUME)
  volume = if storage.start_with?("/", ".")
    File.expand_path(storage, ENGINE_ROOT)
  else
    storage
  end

  script = File.join(ENGINE_ROOT, "remove_time_tracking.rb")
  sh "docker", "run", "--rm",
    "-e", "SECRET_KEY_BASE_DUMMY=1",
    "-v", "#{volume}:/rails/storage",
    "-v", "#{script}:/rails/remove_time_tracking.rb",
    "ghcr.io/basecamp/fizzy:main",
    "bin/rails", "runner", "remove_time_tracking.rb"
end

# Shell out with a clean Bundler env — we're bootstrapping Fizzy's bundle,
# which may not match whatever this process loaded.
def in_fizzy(*cmd)
  Bundler.with_unbundled_env do
    Dir.chdir(FIZZY_PATH) { sh(*cmd) }
  end
end

def ensure_docker_running
  return if system("docker info > /dev/null 2>&1")

  puts "Docker is not running — starting Docker Desktop..."
  system("docker", "desktop", "start")

  print "Waiting for Docker"
  60.times do
    break if system("docker info > /dev/null 2>&1")
    print "."
    sleep 2
  end
  puts

  raise "Docker did not start in time" unless system("docker info > /dev/null 2>&1")
end

def container_running?(name)
  `docker inspect --format '{{.State.Running}}' #{name} 2>/dev/null`.strip == "true"
end

def container_exists?(name)
  system("docker inspect #{name} > /dev/null 2>&1")
end

def image_id(image)
  `docker inspect --format '{{.Id}}' #{image} 2>/dev/null`.strip
end

def container_image_id(name)
  `docker inspect --format '{{.Image}}' #{name} 2>/dev/null`.strip
end

# The container's /rails/storage mount source: named volume name for `-v name:...`,
# absolute host path for `-v /path:...`. Matches the shape of `volume` in prod:start.
def container_storage_mount(name)
  `docker inspect --format '{{range .Mounts}}{{if eq .Destination "/rails/storage"}}{{if eq .Type "volume"}}{{.Name}}{{else}}{{.Source}}{{end}}{{end}}{{end}}' #{name} 2>/dev/null`.strip
end

def start_container(volume)
  secret_key_base, _, status = Open3.capture3("docker", "run", "--rm", GHCR_IMAGE, "bin/rails", "secret")
  raise "Failed to generate SECRET_KEY_BASE" unless status.success?

  docker "run", "-d",
    "--name", CONTAINER_NAME,
    "-p", "8080:80",
    "-e", "SECRET_KEY_BASE=#{secret_key_base.strip}",
    "-e", "DISABLE_SSL=true",
    "-v", "#{volume}:/rails/storage",
    GHCR_IMAGE
end

def docker(*args)
  out, err, status = Open3.capture3("docker", *args)
  return if status.success?

  detail = [ out, err ].map(&:strip).reject(&:empty?).join("\n")
  raise "docker #{args.join(' ')} failed\n#{detail}"
end

def clone_fizzy
  if File.exist?(File.join(FIZZY_PATH, "Gemfile"))
    puts "Fizzy already present at #{FIZZY_PATH}, skipping clone."
  else
    sh "git", "clone", "https://github.com/basecamp/fizzy.git", FIZZY_PATH,
      "--branch", fizzy_ref, "--single-branch", "--depth", "1"
  end
end

def add_engine_to_gemfile
  gemfile = File.join(FIZZY_PATH, "Gemfile")
  engine_line = %(gem "fizzy-time_tracking", path: #{ENGINE_ROOT.inspect})

  if File.read(gemfile).include?("fizzy-time_tracking")
    puts "Engine already in Gemfile, skipping."
  else
    File.open(gemfile, "a") { |f| f.puts "\n#{engine_line}" }
  end
end
