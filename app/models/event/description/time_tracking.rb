module Event::Description::TimeTracking
  private
    def card
      if event.action.time_entry_created?
        event.eventable.card
      else
        super
      end
    end

    def action_sentence(creator, card_title)
      if event.action.time_entry_created?
        "#{creator} logged time on #{card_title}"
      else
        super
      end
    end
end
