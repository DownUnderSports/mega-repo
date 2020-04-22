if (!String.prototype.reverse) {
  // eslint-disable-next-line no-extend-native
  String.prototype.reverse = function() {
    if(this.length > 64) {
      return this.split('').reverse().join('');
    }

    let i, s='';
    for(i = (this.length - 1); i >= 0; i--) {
      s+= this.charAt(i);
    }
    return s;
  };
}
