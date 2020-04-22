# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)


#########################################################
######## RECREATE AUDITS AFTER FUNCTIONAL UPDATE ########
#########################################################

# class BetterRecord::OldLoggedAction < BetterRecord::Base
#   self.table_name = "auditing.old_logged_actions"
# end
#
# def run_seeds
#   table_list = {}
#
#   BetterRecord.const_set(:NewLoggedAction, nil)
#   ct = BetterRecord::OldLoggedAction.count
#   while ct > 0
#     puts "total: #{ct}"
#     BetterRecord::OldLoggedAction.order(:event_id).limit(5000).each do |r|
#       unless table_list[r.table_name]
#         begin
#           BetterRecord::LoggedAction.connection.execute(%Q(SELECT 1 FROM auditing.logged_actions_#{r.table_name}))
#
#           table_list[r.table_name] = Class.new(ActiveRecord::Base)
#           table_list[r.table_name].table_name = "auditing.logged_actions_#{r.table_name}"
#         rescue ActiveRecord::StatementInvalid
#           table_list[r.table_name] = BetterRecord::LoggedAction
#         end
#       end
#
#       BetterRecord.send :remove_const, :NewLoggedAction
#       BetterRecord.const_set(:NewLoggedAction, table_list[r.table_name])
#       BetterRecord::NewLoggedAction.new(r.attributes).save!(validate: false)
#
#       print "total: #{ct}\r" if ((ct -= 1) % 50) == 0
#
#       # print "#{"total: #{BetterRecord::OldLoggedAction.count}, #{r.table_name}: #{BetterRecord::NewLoggedAction.count}".ljust(150)}\r" if ((i += 1) % 100) == 0
#       # p BetterRecord::NewLoggedAction.count
#       r.delete
#     end
#   end
#   run_seeds if BetterRecord::OldLoggedAction.count > 0
# end
#
# run_seeds
