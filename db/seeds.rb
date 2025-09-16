users = [
  { name: "Ada Lovelace", email: "ada@example.com" },
  { name: "Grace Hopper", email: "grace@example.com" }
]

users.each do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |user|
    user.name = attrs[:name]
    user.password = "password123"
  end
end
