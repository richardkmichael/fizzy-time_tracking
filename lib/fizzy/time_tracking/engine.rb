module Fizzy
  module TimeTracking
    class Engine < ::Rails::Engine
      initializer "fizzy_time_tracking.feature_flag" do
        ::Fizzy.class_eval do
          def self.time_tracking?
            true
          end
        end
      end

      initializer "fizzy_time_tracking.assets" do |app|
        app.config.assets.paths << root.join("app/assets/stylesheets")
        app.config.assets.paths << root.join("app/assets/images")
      end

      initializer "fizzy_time_tracking.routes", after: :add_routing_paths do |app|
        app.routes.prepend do
          resources :cards, only: [] do
            scope module: :cards do
              resources :time_entries
            end
          end

          resolve "TimeEntry" do |time_entry, options|
            route_for :card, time_entry.card, options
          end
        end
      end

      config.to_prepare do
        ::Card.include Card::Timeable
        ::Card::Eventable::SystemCommenter.prepend Card::Eventable::SystemCommenter::TimeTracking
        ::Event::Description.prepend Event::Description::TimeTracking

        unless User::DayTimeline::TIMELINEABLE_ACTIONS.include?("time_entry_created")
          User::DayTimeline::TIMELINEABLE_ACTIONS << "time_entry_created"
        end

        unless ::Webhook::PERMITTED_ACTIONS.include?("time_entry_created")
          actions = ::Webhook::PERMITTED_ACTIONS + %w[ time_entry_created ]
          ::Webhook.send(:remove_const, :PERMITTED_ACTIONS)
          ::Webhook.const_set(:PERMITTED_ACTIONS, actions.freeze)
        end
      end

      initializer "fizzy_time_tracking.test_fixtures", after: :load_config_initializers do
        if Rails.env.test?
          require_relative "testing"
        end
      end
    end
  end
end
