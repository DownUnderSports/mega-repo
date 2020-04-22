if(!window.WeakSet) {
  window.weakSetCounter = Date.now() % 1e9;
  window.WeakSet = function WeakSet (data) {
    this.name = '__st' + (Math.random() * 1e9 >>> 0) + (window.weakSetCounter++ + '__');
    data && data.forEach && data.forEach(this.add, this);
  };

  window.WeakSet.prototype.add = function(val) {
    var name = this.name;
    if (!val[name]) Object.defineProperty(val, name, {value: true, writable: true});
    return this;
  };
  window.WeakSet.prototype.delete = function(val) {
    if (!val[this.name]) return false;
    val[this.name] = undefined;
    return true;
  };
  window.WeakSet.prototype.has = function(val) {
    return !!val[this.name];
  };

}
