if (!Array.unique) {
  Array.onlyUnique = function(value, index, s) {
    return s.indexOf(value) === index;
  }

  Array.unique = function(array) {
    return array.filter( Array.onlyUnique )
  }
}
