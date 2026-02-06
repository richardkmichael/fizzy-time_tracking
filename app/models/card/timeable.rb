module Card::Timeable
  extend ActiveSupport::Concern

  included do
    has_many :time_entries, dependent: :destroy
  end

  def total_minutes
    time_entries.sum(:total_minutes)
  end

  def total_duration
    TimeEntry::Duration.new(total_minutes)
  end
end
