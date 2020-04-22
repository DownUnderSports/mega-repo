# [
#   {
#     full: "Basketball", full_gender: "Boys Basketball", abbr: "BB", abbr_gender: "BBB", is_numbered: true
#     info_attributes: {
#       title: "Hoops Classic",
#       first_year: 1996,
#       tournament: "Down Under Hoops Classic",
#       departing_dates: "Sunday, July 14, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/bbb-background.jpg'
#     }
#   },
#   {
#     full: "Basketball", full_gender: "Girls Basketball", abbr: "BB", abbr_gender: "GBB", is_numbered: true
#     info_attributes: {
#       title: "Hoops Classic",
#       first_year: 1996,
#       tournament: "Down Under Hoops Classic",
#       departing_dates: "Sunday, July 14, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/gbb-background.jpg'
#     }
#   },
#   {
#     full: "Cross Country", full_gender: "Cross Country", abbr: "XC", abbr_gender: "XC", is_numbered: false
#     info_attributes: {
#       title: "International Games",
#       first_year: 1997,
#       tournament: "Down Under Gold Coast Classic",
#       departing_dates: "Saturday, June 29, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/xc-background.jpg'
#     }
#   },
#   {
#     full: "Football", full_gender: "Football", abbr: "FB", abbr_gender: "FB", is_numbered: true
#     info_attributes: {
#       title: "Bowl",
#       first_year: 1988,
#       tournament: "Down Under Bowl",
#       departing_dates: "Sunday, June 30, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/fb-background.jpg'
#     }
#   },
#   {
#     full: "Golf", full_gender: "Golf", abbr: "GF", abbr_gender: "GF", is_numbered: false
#     info_attributes: {
#       title: "International Games",
#       first_year: 2003,
#       tournament: "Down Under Sports Cup",
#       departing_dates: "Saturday, July 13, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/gf-background.jpg'
#     }
#   },
#   {
#     full: "Track and Field", full_gender: "Track and Field", abbr: "TF", abbr_gender: "TF", is_numbered: false
#     info_attributes: {
#       title: "International Games",
#       first_year: 2000,
#       tournament: "Down Under International Games",
#       departing_dates: "Saturday, July 06, 2019 and Sunday, July 07, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/tf-background.jpg'
#     }
#   },
#   {
#     full: "Volleyball", full_gender: "Volleyball", abbr: "VB", abbr_gender: "VB", is_numbered: true
#     info_attributes: {
#       title: "International Games",
#       first_year: 1998,
#       tournament: "Down Under Volleyball Invitational",
#       departing_dates: "Saturday, July 13, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/vb-background.jpg'
#     }
#   },
#   {
#     full: "Cheer", full_gender: "Cheer", abbr: "CH", abbr_gender: "CH", is_numbered: false
#     info_attributes: {
#       title: "Bowl",
#       first_year: 1988,
#       tournament: "Down Under Bowl",
#       departing_dates: "Sunday, June 30, 2019",
#       team_count: "1 Default Team",
#       team_size: "1 Million Athletes",
#       description: "Enter Sport Description",
#       bullet_points_array: [],
#       programs_array: [],
#       background_image: '/images/ch-background.jpg'
#     }
#   },
# ].each {|sport| Sport.create(sport) unless Sport.find_by(abbr_gender: sport[:abbr_gender]) }
