module TimeEntry::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    after_create_commit :track_creation
  end

  def event_was_created(event)
    Card::Eventable::SystemCommenter.new(card, event).comment if card.commentable?
    card.touch_last_active_at
  end

  private
    def should_track_event?
      true
    end

    def track_creation
      track_event("created", board: card.board, creator: creator)
    end
end
