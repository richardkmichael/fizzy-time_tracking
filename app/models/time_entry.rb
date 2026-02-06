class TimeEntry < ApplicationRecord
  include Eventable

  attr_accessor :hours, :minutes, :negative

  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  before_validation :combine_hours_and_minutes

  validates :total_minutes, presence: true, numericality: { other_than: 0, only_integer: true }
  validates :date, presence: true
  validate :total_cannot_go_negative, on: :create

  scope :by_date_desc, -> { order(date: :desc, created_at: :desc) }

  after_create_commit :watch_card_by_creator

  delegate :publicly_accessible?, :accessible_to?, :board, :watch_by, to: :card

  def hours_value
    total_minutes / 60
  end

  def minutes_value
    total_minutes % 60
  end

  def duration
    Duration.new(total_minutes.abs)
  end

  def to_partial_path
    "cards/#{super}"
  end

  private
    def combine_hours_and_minutes
      if hours.present? || minutes.present?
        total = hours.to_i * 60 + minutes.to_i
        self.total_minutes = negative ? -total : total
      end
    end

    def total_cannot_go_negative
      if total_minutes&.negative? && (card.total_minutes + total_minutes) < 0
        errors.add(:base, "Cannot remove more time than logged")
      end
    end

    def watch_card_by_creator
      card.watch_by creator
    end
end
