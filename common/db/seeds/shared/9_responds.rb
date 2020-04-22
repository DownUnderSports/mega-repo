# require 'csv'
# path = File.join(__dir__, 'responds.csv')
# count = `wc -l #{path}`.to_i - 1
#
# set_fields = ->(u, fields) do
#   # u.title = fields[:title].presence
#   u.first = fields[:first]
#   # u.middle = fields[:middle].presence
#   u.last = fields[:last]
#   # u.suffix = fields[:suffix].presence
#   u.email = fields[:email].presence
#   u.phone = fields[:phone].presence
# end
#
#
# CSV.foreach(path, headers: true, encoding: 'bom|utf-8') do |row|
#   row = row.to_h.with_indifferent_access
#   begin
#     if row[:dus_id] && (user = User.get(row[:dus_id]))
#       responded = row[:respond_date].presence
#
#
#       mtg_date = row[:meeting_date]
#       if mtg_date.present?
#         meeting = Meeting.by_date(mtg_date).first
#         registration = Meeting::Registration.find_by(meeting_id: meeting.id, user_id: user.id) ||
#                        Meeting::Registration.new(meeting: meeting, user: user)
#         registration.attended = !!row[:meeting_attended].present?
#         registration.duration = row[:meeting_attended].rjust(8, '0') if registration.attended
#         registration.save!
#       end
#
#       user.address = Address.new(
#         Address.normalize(
#           row.slice(*row.keys.select {|k| k.to_s =~ /^address/}).transform_keys {|k| k.to_s.sub('address_', '').to_sym }
#         )
#       ) if row[:address_street].present?
#
#       ik = user.mailings.find_by(category: :infokit) || user.mailings.create(category: :infokit, address: user.address || user.athlete.school.address, is_home: !!user.address)
#
#       unless responded && (ik.created_at.to_date.to_s == responded)
#         ik.created_at = responded.to_date.midnight if responded
#         ik.save!
#       end
#
#       set_fields.call(user, row)
#
#       user.save!
#
#       guardian = user.related_users.where('first ilike ?', "%#{row[:guardian_first]}%").first || User.new
#       guardian.address = user.address if user.address
#
#       set_fields.call(guardian, row.slice(*row.keys.select {|k| (k.to_s =~ /guardian_/) }).transform_keys {|k| k.to_s.sub('guardian_', '').to_sym})
#       guardian.save!
#
#       rel = user.relations.find_by(related_user_id: guardian.id) || user.relations.new(related_user: guardian)
#       rel.relationship = row[:guardian_relationship]
#
#       rel.save!
#
#       if row[:guardian_2_first].present?
#         guardian = user.related_users.where('first ilike ?', "%#{row[:guardian_2_first]}%").first || User.new
#         guardian.address = user.address if user.address
#
#         set_fields.call(guardian, row.slice(*row.keys.select {|k| (k.to_s =~ /guardian_2_/) }).transform_keys {|k| k.to_s.sub('guardian_2_', '').to_sym})
#
#         guardian.save!
#
#         rel = user.relations.find_by(related_user_id: guardian.id) || user.relations.new(related_user: guardian)
#         rel.relationship = row[:guardian_2_relationship]
#
#         rel.save!
#       end
#     else
#       p 'USER NOT FOUND'
#       raise
#     end
#   rescue
#     p '---------'
#     p $!.message
#     p $!.backtrace.first(10)
#     p " "
#     p row
#     p '---------'
#   end
# end
