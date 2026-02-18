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
def fizzy_image_tag
  @fizzy_image_tag ||= ENV.fetch("FIZZY_IMAGE_TAG") { detect_latest_fizzy_image_tag }
end

def fizzy_ref
  @fizzy_ref ||= ENV.fetch("FIZZY_REF") do
    if (sha = fizzy_image_tag[/\Asha-([a-f0-9]+)\z/, 1])
      "fizzy@#{sha}"
    else
      fizzy_image_tag
    end
  end
end

def detect_latest_fizzy_image_tag
  @detected_tag ||= begin
    tag = `gh api /orgs/basecamp/packages/container/fizzy/versions \
      --jq '[.[] | select(.metadata.container.tags | any(. == "main"))]
             | .[0].metadata.container.tags
             | map(select(startswith("sha-") and test("^sha-[a-f0-9]{7}$")))
             | .[0]' 2>/dev/null`.strip
    (tag.empty? || tag == "null") ? "main" : tag
  rescue
    "main"
  end
end

fizzy_gemfile = File.join(FIZZY_PATH, "Gemfile")
ENV["BUNDLE_GEMFILE"] = fizzy_gemfile if File.exist?(fizzy_gemfile)

require "bundler/setup"

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

IMAGE = "fizzy-time_tracking"
DEFAULT_VOLUME = "#{IMAGE}-data"

namespace :prod do
  desc "Build the Docker image (development uses `rake dev:server`)"
  task :build do
    Dir.chdir(ENGINE_ROOT) { sh "docker", "build", "--build-arg", "FIZZY_IMAGE_TAG=#{fizzy_image_tag}", "-t", IMAGE, "." }
  end

  desc "Run the Docker image (rake prod:run[./data] or rake prod:run[my-volume])"
  task :run, [ :storage ] do |_t, args|
    storage = args.fetch(:storage, DEFAULT_VOLUME)
    volume = if storage.start_with?("/", ".")
      File.expand_path(storage, ENGINE_ROOT)
    else
      storage
    end

    secret_key = `docker run --rm #{IMAGE} bin/rails secret`.chomp
    container_id = `docker run -d \
      -p 8080:80 \
      -e SECRET_KEY_BASE=#{secret_key} \
      -e DISABLE_SSL=true \
      -v #{volume}:/rails/storage \
      #{IMAGE}`.chomp
    puts "Container started: #{container_id}"
    puts "URL:   http://localhost:8080"
    puts "Logs:  docker logs -f #{container_id}"
    puts "Stop:  docker stop #{container_id}"
    puts "Sign in:  docker exec #{container_id} bin/rails runner 'puts Identity.find_or_create_by!(email_address: ARGV[0]).magic_links.create!.code' YOUR@EMAIL.COM"
  end
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
