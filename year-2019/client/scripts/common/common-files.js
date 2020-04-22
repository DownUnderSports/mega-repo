var exec = require('child_process').exec,
    glob = require('glob'),
    cpx = require("cpx"),
    base_dir = __dirname + '/../..',
    root_dir = base_dir + '/..',
    public_dir = base_dir + '/public/common',
    scripts_dir = base_dir + '/scripts/common',
    src_dir = base_dir + '/src/common',
    common_dir = root_dir + '/vendor/common';

function transformDir(dir) {
  switch (String(dir)) {
    case 'public':
      return public_dir
    case 'scripts':
      return scripts_dir
    default:
      return src_dir + '/' + dir
  }
}


exports.watch = function addWatcher(dir) {
  cpx.watch(common_dir + '/' + dir + '/**', transformDir(dir), { clean: true, dereference: true })
  .on("copy", (e) => console.log("copy: " + e.srcPath))
  .on("remove", (e) => console.log("remove: " + e.srcPath))
  .on("watch-ready", (e) => console.log("watch-ready"))
  .on("watch-error", (err) => console.log("watch-error: ", err))
};

exports.copy = function copyDir(dir) {
  cpx.copy(common_dir + '/' + dir + '/**', transformDir(dir), { clean: true, dereference: true })
};

// [
//   'js',
//   'assets'
// ].map((dir) => addWatchers(dir))

(function(args) {
  "use strict";

  args = args || []

  var selected = exports[args[0]];
  if(selected){
    var sendIt = [...args.slice(1)]
    sendIt.map((d) => selected(d))
  }
})(process.argv.slice(2))
