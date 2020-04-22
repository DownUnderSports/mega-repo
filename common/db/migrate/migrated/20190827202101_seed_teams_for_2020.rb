class SeedTeamsFor2020 < ActiveRecord::Migration[5.2]
  def up
    if Sport.all.size > 0
      set_db_year 2020

      [
        ["BB", '2020-07-12', '2020-07-21', '2020-07-20'],
        ["XC", '2020-06-27', '2020-07-06', '2020-07-02'],
        ["FB", '2020-06-28', '2020-07-07', '2020-07-04'],
        ["GF", '2020-07-11', '2020-07-20', '2020-07-16'],
        ["VB", '2020-07-11', '2020-07-20', '2020-07-17'],
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
      base_date = Date.parse('2020-07-04')
      sport_id = Sport::TF.id

      [
        State.where(conference: first_group),
        State.where.not(conference: first_group)
      ].map do |query|
        query.where_not_exists(:teams, sport_id: sport_id).each do |state|
          p Team.create(
            name: "#{state.abbr} TF",
            sport_id: sport_id,
            state: state,
            departing_date: base_date,
            returning_date: base_date + 9,
            gbr_date: base_date + 5
          )
        end

        base_date += 1
      end; nil
      set_db_year "public"
    end
  end
end
