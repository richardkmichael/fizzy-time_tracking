module FizzyTimeTracking
  class InstallGenerator < Rails::Generators::Base
    desc "Install Fizzy Time Tracking: inject button and stylesheet into host views"

    CONTAINER_PATH = "app/views/cards/_container.html.erb"
    DRAFT_CONTAINER_PATH = "app/views/cards/drafts/_container.html.erb"
    CONTAINER_ANCHOR = '<%= render "cards/display/perma/tags", card: card %>'
    CONTAINER_LINE = '<%= render "cards/time_entries/button", card: card if Fizzy.time_tracking? %>'

    HEAD_PATH = "app/views/layouts/shared/_head.html.erb"
    HEAD_ANCHOR = '<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>'
    HEAD_LINE = '<%= stylesheet_link_tag "fizzy/time_tracking", "data-turbo-track": "reload" if Fizzy.time_tracking? %>'

    def inject_button_into_card_header
      inject_line_after CONTAINER_PATH, CONTAINER_ANCHOR, CONTAINER_LINE, indent: 10
    end

    def inject_button_into_draft_card_header
      inject_line_after DRAFT_CONTAINER_PATH, CONTAINER_ANCHOR, CONTAINER_LINE, indent: 10
    end

    def inject_stylesheet_into_head
      inject_line_after HEAD_PATH, HEAD_ANCHOR, HEAD_LINE, indent: 2
    end

    def install_migrations
      rake "fizzy_time_tracking_engine:install:migrations"
    end

    def display_post_install
      say ""
      say "Fizzy Time Tracking installed. Next steps:", :green
      say "  rails db:migrate"
      say ""
    end

    private
      def inject_line_after(path, anchor, line, indent: 0)
        file = File.join(destination_root, path)

        unless File.exist?(file)
          say_status :skip, "#{path} not found", :yellow
          return
        end

        if File.read(file).include?(line)
          say_status :skip, "already present in #{path}", :yellow
          return
        end

        inject_into_file path, after: "#{anchor}\n" do
          "#{" " * indent}#{line}\n"
        end
      end
  end
end
