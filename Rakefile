# Fizzy is the host app for this engine — an external Rails app with its own
# Gemfile, cloned into test/fizzy/ by `rake setup`.
#
# Standard engines keep a test/dummy app *inside* the engine's bundle, so
# APP_RAKEFILE + rails/tasks/engine.rake just works. Here, Fizzy has a
# separate bundle. We bridge that gap by pointing BUNDLE_GEMFILE at Fizzy's
# Gemfile before Bundler loads — Fizzy's bundle includes this engine as a
# path gem, so everything resolves. On first clone (before `rake setup`),
# Fizzy isn't present yet; we fall back to the engine's own Gemfile so that
# gem-building tasks still work.

ENGINE_ROOT = __dir__
FIZZY_PATH  = ENV.fetch("FIZZY_PATH") { File.expand_path("test/fizzy", ENGINE_ROOT) }
FIZZY_REF   = ENV.fetch("FIZZY_REF", "main")

fizzy_gemfile = File.join(FIZZY_PATH, "Gemfile")
ENV["BUNDLE_GEMFILE"] = fizzy_gemfile if File.exist?(fizzy_gemfile)

require "bundler/setup"
require "bundler/gem_tasks"

app_rakefile = File.join(FIZZY_PATH, "Rakefile")
if File.exist?(app_rakefile)
  APP_RAKEFILE = app_rakefile
  Dir.chdir(FIZZY_PATH)
  load "rails/tasks/engine.rake"
end

task default: :test

if File.exist?(app_rakefile)
  engine_test_dirs = Dir[File.join(ENGINE_ROOT, "test", "*/")]
    .reject { |d| d.end_with?("fizzy/", "fixtures/") }

  desc "Run engine tests via Fizzy host app"
  task :test do
    in_fizzy "bin/rails", "test", *engine_test_dirs
  end
else
  task :test do
    abort "Fizzy host app not found at #{FIZZY_PATH}. Run `rake setup` first."
  end
end

desc "Clone and configure Fizzy host app for running engine tests"
task :setup do
  clone_fizzy
  add_engine_to_gemfile

  in_fizzy "bundle", "install"
  in_fizzy "bin/rails", "generate", "fizzy_time_tracking:install"
  in_fizzy "bin/rails", "db:prepare"
end

# Shell out with a clean Bundler env — we're bootstrapping Fizzy's bundle,
# which may not match whatever this process loaded.
def in_fizzy(*cmd)
  Bundler.with_unbundled_env do
    Dir.chdir(FIZZY_PATH) { sh(*cmd) }
  end
end

def clone_fizzy
  if File.directory?(FIZZY_PATH)
    puts "Fizzy already present at #{FIZZY_PATH}, skipping clone."
  else
    sh "git", "clone", "https://github.com/basecamp/fizzy.git", FIZZY_PATH,
      "--branch", FIZZY_REF, "--single-branch", "--depth", "1"
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
