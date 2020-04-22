# encoding: utf-8
# frozen_string_literal: true

require_dependency 'import'

module Import
  class FindDupsJob < ApplicationJob
    queue_as :importing

    def perform(**opts)
      csv = +""
      max_cols = 1
      idx = 0

      save_csv = -> do
        object_path = "tmp/dup_lists/#{rand}-#{Time.zone.now.to_i}.csv"
        save_to_s3 object_path, CSV.generate_line([
            'merge_into_id',
            'dus_id',
            'url',
            *(Array.new(max_cols).map.with_index{|v, i| "candidate_#{i+1}"})
        ]) + csv

        FileMailer.
          with(
            object_path: object_path,
            compress: true,
            file_name: "dup_checks_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv",
            email: 'it@downundersports.com',
            subject: 'Possible Duplicate Athletes',
            message: 'Decompress and give to someone to fill in merge_into_id',
            delete_file: true
          ).
          send_s3_file.
          deliver_later(queue: :staff_mailer)

        csv = +""
        max_cols = 1
        idx = 0
      end

      last_id = 0

      while User.athletes.visible.order(:id).where("id > ?", last_id).exists?
        user = User.athletes.visible.order(:id).where("id > ?", last_id).take
        last_id = user&.id || (last_id + 1)
        next unless user.persisted? && User[user.id]

        values = [
          nil,
          user.dus_id,
          user.admin_url
        ]

        users = similar_users user.id

        if users.exists?
          if users.size == 1
            begin
              u = users.take
              raise "IMPERFECT MATCH" unless (u.first.downcase.gsub(/[^a-z]/, '') == user.first.downcase.gsub(/[^a-z]/, '')) && (u.last.downcase.gsub(/[^a-z]/, '') == user.last.downcase.gsub(/[^a-z]/, ''))
              User.merge_users! *(u.id < user.id ? [u, user] : [user, u])
              next
            rescue
              puts users.to_a.map(&:as_json) rescue nil
              puts user.as_json rescue nil
              puts $!.message
              puts $!.backtrace
              values << users.first.admin_url
            end
          else
            max_cols = [max_cols, users.size].max
            values |= users.map(&:admin_url)
          end

          csv << CSV.generate_line(values)

          save_csv.call if (idx += 1) >= 20_000
        end
      end
    end

    def similar_users(id)
      user = User[id]

      user.athlete.school.users.
        joins(:athlete).
        where.not(id: user.id).
        where(gender: [user.gender, 'U']).
        where(
          "(lower(users.first) || ' ' || lower(users.last)) % (:first || ' ' || :last)",
          first: user.first.downcase,
          last: user.last.downcase
        ).
        where(
          *(
            user.athlete.grad.present? ?
            ["(athletes.grad IS NULL) OR (athletes.grad = ?)", user.athlete.grad] :
            ["(athletes.grad IS NOT NULL)"]
          )
        )
    rescue
      []
    end
  end
end
