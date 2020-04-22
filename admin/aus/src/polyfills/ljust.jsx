if (!String.prototype.padEnd) {
  // eslint-disable-next-line no-extend-native
  String.prototype.padEnd = function padEnd(targetLength, padString) {
    targetLength = targetLength >> 0; //truncate if number, or convert non-number to 0;
    padString = String(typeof padString !== 'undefined' ? padString : ' ');
    if (this.length >= targetLength) {
      return String(this);
    } else {
      targetLength = targetLength - this.length;
      if (targetLength > padString.length) {
        padString += padString.repeat(1 + (targetLength / padString.length)); //append to original to ensure we are longer than needed
      }
      return String(this) + padString.slice(0, targetLength);
    }
  };
}

if (!String.prototype.ljust) {
  // eslint-disable-next-line no-extend-native
  String.prototype.ljust = String.prototype.padEnd
}
