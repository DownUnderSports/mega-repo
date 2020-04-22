if(!Array.equal){
  Array.equal = function(first, second) {
    if(first === second) return true

    if(!Array.isArray(first) || !Array.isArray(second) || (first.length !== second.length)) return false

    for (var i = 0; i < first.length; i++) {
      if(second[i] !== first[i]) return false
    }

    return true
  }
}
if (!Array.prototype.isEqualTo){
  // eslint-disable-next-line no-extend-native
  Array.prototype.isEqualTo = function(array) {
    return Array.equal(this, array)
  };
}
