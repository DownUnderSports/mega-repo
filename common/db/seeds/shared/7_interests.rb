# [
#   { id: 1,  level: "Traveling",             contactable: true  },
#   { id: 2,  level: "Sending Deposit",       contactable: true  },
#   { id: 3,  level: "Interested",            contactable: true  },
#   { id: 4,  level: "Curious",               contactable: true  },
#   { id: 5,  level: "Unknown",               contactable: true  },
#   { id: 6,  level: "Supporter - Not Going", contactable: true  },
#   { id: 7,  level: "Open Tryout",          contactable: true  },
#   { id: 8,  level: "Next Year",             contactable: false },
#   { id: 9,  level: "No Respond",            contactable: false },
#   { id: 10, level: "Not Going",             contactable: false },
#   { id: 11, level: "Never",                 contactable: false }
# ].each do |i|
#   Interest.create!(**i) unless Interest.find_by(id: i[:id])
# end
