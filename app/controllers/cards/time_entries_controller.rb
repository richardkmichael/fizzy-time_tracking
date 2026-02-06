class Cards::TimeEntriesController < ApplicationController
  include CardScoped

  before_action :set_time_entry, only: %i[ show edit update destroy ]
  before_action :ensure_creatorship, only: %i[ edit update destroy ]

  def index
    set_page_and_extract_portion_from @card.time_entries.by_date_desc
  end

  def create
    @time_entry = @card.time_entries.build(time_entry_params)
    @time_entry.negative = params[:commit] == "remove"

    if @time_entry.save
      @system_comment = @card.comments.where(creator: @card.account.system_user).order(created_at: :desc).first

      respond_to do |format|
        format.turbo_stream
        format.json { head :created, location: card_time_entry_path(@card, @time_entry, format: :json) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    @time_entry.update!(time_entry_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @time_entry.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_time_entry
      @time_entry = @card.time_entries.find(params[:id])
    end

    def ensure_creatorship
      head :forbidden if Current.user != @time_entry.creator
    end

    def time_entry_params
      params.expect(time_entry: [ :hours, :minutes, :date, :description ])
    end
end
