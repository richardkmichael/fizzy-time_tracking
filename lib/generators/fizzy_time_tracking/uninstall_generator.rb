module FizzyTimeTracking
  class UninstallGenerator < Rails::Generators::Base
    desc "Uninstall Fizzy Time Tracking: remove injected lines from host views"

    CONTAINER_PATH = "app/views/cards/_container.html.erb"
    CONTAINER_LINE = '          <%= render "cards/time_entries/button", card: card if Fizzy.time_tracking? %>'

    HEAD_PATH = "app/views/layouts/shared/_head.html.erb"
    HEAD_LINE = '  <%= stylesheet_link_tag "fizzy/time_tracking", "data-turbo-track": "reload" if Fizzy.time_tracking? %>'

    def remove_button_from_card_header
      remove_line CONTAINER_PATH, CONTAINER_LINE
    end

    def remove_stylesheet_from_head
      remove_line HEAD_PATH, HEAD_LINE
    end

    def display_post_uninstall
      say ""
      say "Fizzy Time Tracking removed.", :green
      say "You may also want to run: rails db:migrate:down VERSION=20260205000001"
      say ""
    end

    private
      def remove_line(path, line)
        file = File.join(destination_root, path)

        unless File.exist?(file)
          say_status :skip, "#{path} not found", :yellow
          return
        end

        gsub_file path, /#{Regexp.escape(line)}\n/, ""
        say_status :remove, path, :green
      end
  end
end
