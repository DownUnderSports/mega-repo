var exec = require('child_process').exec,
    glob = require('glob')



var inspect = (...args) => {
  return console.log(util(...args, false, null));
}

exports.createStyles = function createStyles(watch){
  "use strict";

  glob('./src/**/*.styl', function(er, files){
    console.log(files);

    for(var i = 0; i < files.length; i++) {
      if(watch === 'watch'){
        exec('stylus -I src -u nib -w ' + files[i])
      } else {
        exec('stylus -I src -u nib ' + files[i])
      }
    }
  })
}

exports.run = function() {
  "use strict";
  var runCompress = new exports.createStyles()
};

exports.watch = function() {
  "use strict";
  exports.createStyles('watch')
};

(function(args) {
  "use strict";

  var selected = void(0);
  for(let a = 0; a < args.length; a++) {
    selected = exports[args[a]];
    if(selected){
      selected(...args.splice(a, 1))
    }
  }
})(process.argv.slice(2))
