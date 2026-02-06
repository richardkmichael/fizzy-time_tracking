class TimeEntry::Duration
  MINUTES_PER_HOUR = 60
  HOURS_PER_DAY = 8

  attr_reader :total_minutes

  def initialize(total_minutes)
    @total_minutes = total_minutes.to_i
  end

  def days
    total_minutes / (HOURS_PER_DAY * MINUTES_PER_HOUR)
  end

  def hours
    (total_minutes % (HOURS_PER_DAY * MINUTES_PER_HOUR)) / MINUTES_PER_HOUR
  end

  def remaining_minutes
    total_minutes % MINUTES_PER_HOUR
  end

  def to_s
    parts = []
    parts << "#{days}d" if days > 0
    parts << "#{hours}h" if hours > 0
    parts << "#{remaining_minutes}m"
    parts.join(" ")
  end
end
