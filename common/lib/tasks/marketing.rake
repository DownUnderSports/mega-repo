# encoding: utf-8
# frozen_string_literal: true

pre_mark_message = 'Marked for infokit pre-mail'
halloween_offer_message = 'Sent Halloween Offer'
kit_messages = [
  'Sent Infokit Email',
  'Sent Kit Followup Email',
  pre_mark_message,
  halloween_offer_message
]

namespace :marketing do
  namespace :halloween do
    desc 'Send halloween emails to uncontacted-this-year last-year responds'
    task send_emails: :environment do
      emails = ['ISSI-USA@downundersports.com']
      User.
        visible.
        athletes.
        where(interest_id: Interest::Unknown.id).
        where(responded_at: nil).
        where_exists(:notes, "message like ?", '2019 Respond Date:%').
        where_not_exists(:messages, "message like ?", '2019 Traveler%').
        where_not_exists(:messages, "message ilike ?", 'Sent%kit%email').
        where_not_exists(:messages, message: [pre_mark_message, halloween_offer_message]).
        where_not_exists(:mailings, category: :infokit).
        where_not_exists(:staff_assignments).
        where_not_exists(:messages, staff_id: Staff.where.not(id: auto_worker.category_id).select(:id)).
        order(:id).
        limit(300).
        each do |u|
          begin
            if has_ik = u.has_infokit?
              raise "infokit_already_sent"
            end

            ik_message = kit_messages | [ "Sent Infokit Email for #{u.team&.sport&.abbr}" ]

            user_emails = [
              u.ambassador_email,
              *u.related_users.
                where.not(email: nil).
                where_not_exists(:contact_histories, message: ik_message).
                map(&:ambassador_email)
            ].select(&:present?).uniq

            if user_emails.present?
              u.contact_histories.create!(message: halloween_offer_message, category: :email, staff_id: auto_worker.category_id)

              emails |= user_emails
            end
          rescue
            begin
              puts u.basic_name
              puts u.admin_url
            rescue
            end
            puts $!.message
            puts $!.backtrace
          end
        end

        emails.in_groups_of(250, false).each do |e_group|
          HolidayMailer.with(email: e_group).halloween_offer.deliver_later(queue: :mass_mailer)
        end
    end

    desc 'Send list of halloween_offer users - (rails marketing:halloween:send_csv)'
    task send_csv: :environment  do
      csv = +""
      csv << CSV.generate_line(%w[ dus_id first last school_name school_city school_state sport_abbr admin_url video_url payment_url ])
      User.
        athletes.
        where(
          id: User::Message.
                halloween_offers.
                select(:user_id)
        ).
        split_batches_values do |user|
          csv << CSV.generate_line([
            user.dus_id,
            user.first,
            user.last,
            (sch = user.athlete&.school)&.name,
            (addr = sch&.address)&.city,
            addr&.state&.abbr,
            (user.team&.sport || user.athlete&.sport)&.abbr_gender,
            user.admin_url,
            "https://www.downundersports.com/videos/i/#{user.dus_id}",
            "https://www.downundersports.com/#{user.traveler ? 'payment' : 'deposit'}/#{user.dus_id}"
          ])
        end

      f_name = "halloween-offer-sent.csv"

      object_path, _ = save_tmp_csv f_name, csv

      FileMailer.
        with(
          object_path: object_path,
          compress: false,
          file_name: f_name,
          email: 'it@downundersports.com',
          subject: "Sent Halloween Offer",
          message: "Here's the CSV for Vern",
          delete_file: true
        ).
        send_s3_file.
        deliver_later(queue: :staff_mailer)
    end
  end

  namespace :uncontacted do
    desc 'Send emails to uncontacted-this-year last-year responds'
    task send_emails: :environment do
      gayle =
        User.
          find_by(
            category_type: BetterRecord::PolymorphicOverride.all_types(Staff),
            first: 'Gayle',
            last: "O'Scanlon"
          )

      i = 0
      User.
        visible.
        athletes.
        where(interest_id: Interest::Unknown.id).
        where(responded_at: nil).
        where_exists(:notes, "message like ?", '2019 Respond Date:%').
        where_not_exists(:traveler).
        where_not_exists(:messages, "message ilike ?", 'Sent%kit%email').
        where_not_exists(:messages, message: [pre_mark_message, halloween_offer_message]).
        where_not_exists(:mailings, category: :infokit).
        where_not_exists(:staff_assignments).
        where_not_exists(:messages, staff_id: Staff.where.not(id: auto_worker.category_id).select(:id)).
        order(:id).
        limit(300).
        each do |u|
          begin
            if has_ik = u.has_infokit?
              raise "infokit_already_sent"
            end

            ik_message = kit_messages | [ "Sent Infokit Email for #{u.team&.sport&.abbr}" ]

            emails = [
              u.ambassador_email,
              *u.related_users.
                where.not(email: nil).
                where_not_exists(:contact_histories, message: ik_message).
                map(&:ambassador_email)
            ].select(&:present?)

            if emails.present?
              u.contact_histories.create!(message: pre_mark_message, category: :email, staff_id: auto_worker.category_id)

              Staff::Assignment.create!(
                user: user,
                assigned_to: gayle,
                assigned_by: auto_worker,
                reason: 'Respond'
              )

              InfokitMailer.send_infokit(
                u.category_id,
                emails,
                u.dus_id,
                true
              ).deliver_later(queue: :mass_mailer)

              i += 1
            end
          rescue
            begin
              puts u.basic_name
              puts u.admin_url
            rescue
            end
            puts $!.message
            puts $!.backtrace
          end
          break if i > 499
        end
    end

    desc 'Send list of pre-mail infokits - (rails marketing:uncontacted:send_csv[2019-10-21,sampson@downundersports.com])'
    task :send_csv, [:date, :email]  => :environment  do |t, args|
      args.with_defaults(email: 'it@downundersports.com', date: (User::Message.premail_infokits.try(:maximum, :created_at)&.in_time_zone || Time.zone.now).to_s)
      puts args
      date = Date.parse args.date.presence || Date.today.to_s
      csv = +""
      csv << CSV.generate_line(%w[ dus_id first last school_name school_city school_state sport_abbr is_alumni admin_url video_url payment_url ])
      User.
        athletes.
        where(
          id: User::Message.
                premail_infokits.
                where(
                  User::Message.
                    arel_table[:created_at].
                    between(date.midnight..date.end_of_day)
                ).
                select(:user_id)
        ).
        split_batches_values do |user|
          csv << CSV.generate_line([
            user.dus_id,
            user.first,
            user.last,
            (sch = user.athlete&.school)&.name,
            (addr = sch&.address)&.city,
            addr&.state&.abbr,
            (user.team&.sport || user.athlete&.sport)&.abbr_gender,
            user.messages.find_by(message: '2019 Traveler') ? 'Yes' : (user.messages.find_by('message like ?', '2019 Traveler%Cancel%') ? 'Cancel' : nil),
            user.admin_url,
            "https://www.downundersports.com/videos/i/#{user.dus_id}",
            "https://www.downundersports.com/#{user.traveler ? 'payment' : 'deposit'}/#{user.dus_id}"
          ])
        end

      f_name = "2019-responds_#{date.to_s}.csv"

      object_path, _ = save_tmp_csv f_name, csv

      FileMailer.
        with(
          object_path: object_path,
          compress: false,
          file_name: f_name,
          email: args.email.presence || 'it@downundersports.com',
          subject: "Marked for infokit pre-mail: #{date.to_s}",
          message: "Here's the CSV for Vern",
          delete_file: true
        ).
        send_s3_file.
        deliver_later(queue: :staff_mailer)
    end
  end
end
