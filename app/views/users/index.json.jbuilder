json.array!(@users) do |user|
  json.extract! user, :id, :name, :email, :password_digest, :remember_digest, :admin, :activation_digest, :activated, :activated_at
  json.url user_url(user, format: :json)
end
