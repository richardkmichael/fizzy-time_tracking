json.cache! time_entry do
  json.(time_entry, :id)

  json.total_minutes time_entry.total_minutes
  json.date time_entry.date
  json.description time_entry.description

  json.created_at time_entry.created_at.utc
  json.updated_at time_entry.updated_at.utc

  json.creator time_entry.creator, partial: "users/user", as: :user

  json.card do
    json.id time_entry.card_id
    json.url card_url(time_entry.card_id)
  end

  json.url card_time_entry_url(time_entry.card_id, time_entry.id)
end
