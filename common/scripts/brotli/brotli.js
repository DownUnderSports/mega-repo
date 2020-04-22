var exec = require('child_process').exec,
    path = require('path'),
    brotli = path.join(__dirname, './brotli');

module.exports.compress = function(inFile, outFile, cb) {
  if(typeof outFile === 'function') {
    cb = outFile;
    outFile = void(0)
  }

  outFile = outFile || (inFile + '.br')

  exec(brotli + ' -7fo \'' + outFile + '\' ' + inFile, error => {
    if(cb) {
      cb(outFile, error)
    } else if(error) {
      console.info('failed to add ' + outFile, error)
    } else {
      console.info('added ' + outFile)
    }
  });
};
