# require 'csv'
# path = File.join(__dir__, 'schools.csv')
# count = `wc -l #{path}`.to_i - 1
#
# i = 0
#
# CSV.foreach(path, headers: true, encoding: 'bom|utf-8') do |row|
#   row = row.to_h.with_indifferent_access
#   row[:verified] = true
#   sch = School.create(
#     address_attributes: {
#       **Address.normalize(row)
#     },
#     **row.slice(*School.attribute_names).deep_symbolize_keys
#   ) unless School.find_by(pid: row[:pid], name: row[:name])
#
#   print "#{i += 1} of #{count} schools      \r"
# end
# puts "#{count} of #{count} schools                         "
