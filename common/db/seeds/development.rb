# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
User.create!(
  dus_id: 'AAAAAA',
  first: 'Test',
  last: 'User',
  gender: 'M',
  email: 'sampsonsprojects@gmail.com',
  category: Athlete.new(
    school: School.first,
    source: Source.first,
    sport: Sport.first,
    grad: 2019,
    original_school_name: School.first.name
  )
) unless User.find_by(dus_id: 'AAAAAA')
