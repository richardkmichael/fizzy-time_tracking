class Notifier::TimeEntryEventNotifier < Notifier
  delegate :creator, to: :source

  private
    def recipients
      card.watchers.without(creator)
    end

    def card
      source.eventable.card
    end
end
