class SeedTeamsFor2021 < ActiveRecord::Migration[5.2]
  def up
    if Sport.all.size > 0
      set_db_year 2021

      [
        ["XC", '2021-06-26', '2021-07-05', '2021-07-01'],
        ["CH", '2021-06-27', '2021-07-06', '2021-07-03'],
        ["FB", '2021-06-27', '2021-07-06', '2021-07-03'],
        ["GF", '2021-07-10', '2021-07-19', '2021-07-15'],
        ["VB", '2021-07-10', '2021-07-19', '2021-07-16'],
        ["BB", '2021-07-11', '2021-07-20', '2021-07-19'],
      ].each do |sp, dep, ret, gbr|
        Sport.where(abbr: sp).each do |sport|
          State.where_not_exists(:teams, sport_id: sport.id).each do |state|
            p Team.create(
              name: "#{state.abbr} #{sport.abbr_gender}",
              sport: sport,
              state: state,
              departing_date: dep,
              returning_date: ret,
              gbr_date: gbr
            )
          end
        end
      end; nil

      first_group = %w[ Pacific Mountain ]
      base_date = Date.parse('2021-07-03')
      sport_id = Sport::TF.id

      [
        [
          State.where(conference: first_group),
          '2021-07-08'
        ],
        [
          State.where.not(conference: first_group),
          '2021-07-12'
        ]
      ].map do |query, gbr_date|
        query.where_not_exists(:teams, sport_id: sport_id).each do |state|
          p Team.create(
            name: "#{state.abbr} TF",
            sport_id: sport_id,
            state: state,
            departing_date: base_date,
            returning_date: base_date + 9,
            gbr_date: gbr_date
          )
        end

        base_date += 1
      end; nil

      set_db_year "public"
    end
  end
end
