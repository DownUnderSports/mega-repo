# [
#   { value: 'child', inverse: 'parent' },
#   { value: 'grandchild', inverse: 'grandparent' },
#   { value: 'ward', inverse: 'guardian' },
#   { value: 'auncle', inverse: 'niephew' },
#   { value: 'sibling', inverse: 'sibling' },
#   { value: 'cousin', inverse: 'cousin' },
#   { value: 'friend', inverse: 'friend' },
# ].each {|rel| User::RelationshipType.new(rel).save }
