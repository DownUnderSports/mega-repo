import 'react-component-templates/polyfills';
import 'polyfills/changed'
import 'polyfills/console'
import 'polyfills/equal'
import 'polyfills/find'
import 'polyfills/find-index'
import 'polyfills/ljust'
import 'polyfills/rjust'
import 'polyfills/reverse'
import 'polyfills/unique'
import 'polyfills/weak-set'
import 'polyfills/custom-event'

if(!String.prototype.trim) {
  // eslint-disable-next-line no-extend-native
  String.prototype.trim = function() {
    return String(this).replace(/^\s+|\s+$/g, '');
  };
}

if(!String.prototype.capitalize) {
  // eslint-disable-next-line no-extend-native
  String.prototype.capitalize = function() {
    var string = String(this);
    return string.charAt(0).toUpperCase() + string.slice(1);
  };
}

if(!String.prototype.titleize) {
  // eslint-disable-next-line no-extend-native
  String.prototype.titleize = function() {
    var string = String(this);
    var string_array = string.replace(/%20/g, ' ').split(' ');
    string_array = string_array.map(function(str) {
       return str.capitalize();
    });

    return string_array.join(' ');
  };
}

if(!String.prototype.underscore) {
  // eslint-disable-next-line no-extend-native
  String.prototype.underscore = function() {
    var string = String(this);
    var string_array = string.replace(/%20/g, ' ').split(' ');
    string_array = string_array.map(function(str) {
       return str.toLowerCase();
    });

    return string_array.join('_');
  };
}

if(!String.presence) {
  // eslint-disable-next-line no-extend-native
  String.presence = function(value) {
    if(value === undefined || value === null) return '';

    return "" + value;
  };
}
