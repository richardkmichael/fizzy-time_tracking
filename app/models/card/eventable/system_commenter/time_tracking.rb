module Card::Eventable::SystemCommenter::TimeTracking
  private
    def comment_body
      if event.action == "time_entry_created"
        body = if event.eventable.total_minutes.negative?
          "#{creator_name} <strong>removed</strong> #{time_entry_duration}"
        else
          "#{creator_name} <strong>added</strong> #{time_entry_duration}"
        end

        if event.eventable.description.present?
          body += "<br>#{h event.eventable.description}"
        end

        body
      else
        super
      end
    end

    def time_entry_duration
      h event.eventable.duration.to_s
    end
end
