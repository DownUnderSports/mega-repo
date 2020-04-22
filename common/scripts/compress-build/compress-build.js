var exec = require('child_process').exec,
    fs = require('fs'),
    path = require('path'),
    brotli = require('../brotli'),
    zlib = require('zlib');
    util = require('util').inspect;

var inspect = (...args) => {
  return console.log(util(...args, false, null));
}

exports.compressBuild = function compressBuild(buildPath, fileList){
  "use strict";

  var scanFiles = function scanFiles(dir, sync = false) {
    return sync ? fs.readdirSync(dir).slice(0) : new Promise(function(res, rej) {
      fs.readdir(dir, (err, files) => {
        if(err) {
          rej(err)
        } else {
          res(files)
        }
      })
    })
  }

  var compressFile = file => new Promise((resolve, reject) => {
    brotli.compress(file, (brPath, e) => {
      if(e){
        reject(e)
      } else {
        console.info('added ' + brPath)
        const gzip = zlib.createGzip(),
              inp = fs.createReadStream(file),
              out = fs.createWriteStream(file + '.gz'),
              stream = inp.pipe(gzip).pipe(out);
        stream.on('close', () => {
          resolve([file, brPath, file + '.gz'])
        })
      }
    })
  })

  var loopCompressable = (dir, file) => new Promise((res, rej) => {
    var name = file.replace(dir, '')
    fs.lstat(file, (err, stats) => {
      if(err) {
        return rej(err); //Handle error
      } else if(stats.isDirectory()) {
        compressFiles(file + '/', scanFiles(file)).then(r => {
          while((r instanceof Array) && (r.length === 1)) {
            r = r[0]
          }
          if(!(r instanceof Array)) {
            r = [r]
          }
          res([name, r])
        })
      } else {
        compressFile(file).then(r => res(r.map(f => f.replace(dir, ''))))
      }
    });
  })

  var compressFiles = function compressFiles(dir, getFiles) {
    var addedList = [], addPromise, compressFile;

    dir = dir || path.join(__dirname, '../../../build/');
    getFiles = Promise.resolve(getFiles || scanFiles(dir));

    addPromise = promise => {
      addedList.push(promise)
    }

    return getFiles.then(files => {
      for(let i = 0; i < files.length; i++) {
        let file = dir + files[i];

        if(!(/\.(br|gz)(otli|ip)?$/.test(file))) {
          addPromise(loopCompressable(dir, file))
        }
      }
      return Promise.all(addedList).then(files => files.map((f) => [f[0], f.slice(1)]))
    })
  };

  var deleteExisting = function deleteExisting(dir, getFiles) {
    "use strict";
    var addedList = [];

    dir = dir || path.join(__dirname, '../../../build/');
    getFiles = Promise.resolve(getFiles || scanFiles(dir));

    return getFiles.then(files => {
      for(let i = 0; i < files.length; i++) {
        let file = dir + files[i];

        if(/\.(br|gz)(otli|ip)?$/.test(file)) {
          addedList.push(new Promise((resolve, reject) => {
            fs.unlink(file, (err) => {
              if(err) {
                throw err;
              }
              console.log('deleted ' + file);
              resolve(file)
            })
          }))
        }
      }
      return Promise.all(addedList)
    })
  }



  buildPath = buildPath || path.join(__dirname, '../../../build/');
  fileList = fileList || scanFiles(buildPath)

  return {
    compressFiles: () => compressFiles(buildPath, fileList),
    deleteExisting: () => deleteExisting(buildPath, fileList),
    buildPath,
    fileList
  }
}

var getSpaces = function getSpaces(nesting) {
  "use strict";
  var spaceStr = ''
  for(let n = 0; n < nesting; n++) {
    spaceStr = spaceStr + '  '
  }
  return spaceStr
}

var printArray = function printArray(arr, nesting) {
  "use strict";
  nesting = nesting || 0;

  console.log(arr)
  var spaces = getSpaces(nesting), str = '[\n  ' + spaces;

  for(var i = 0; i < arr.length; i++) {
    const cell = arr[i];
    if(cell instanceof Array) {
      str = str + printArray(cell, nesting + 1) + ',\n'
    } else {
      str = spaces + '  ' + cell;
      if(arr[i + 1] instanceof Array) {
        str = str + ' => '
      } else {
        str = str + ',\n'
      }
    }
  }
  return str + '\n' + spaces + ']'
}

var arrToHash = function arrToHash(arr) {
  "use strict";
  var h = {},
      last = void(0),
      any = false;
  for(var i = 0; i < arr.length; i++) {
    const cell = arr[i];
    if(cell instanceof Array) {
      if((cell[1] instanceof Array) && !(cell[0] instanceof Array)) {
        arr[i] = {}
        arr[i][cell[0]] = arrToHash(cell[1])
        h[cell[0]] = arr[i][cell[0]]
      } else {
        if(arr.length === 1) {
          return arrToHash(arr[0]);
        } else {
          return cell.map(c => arrToHash(c))
        }
      }
    } else {
      any = true;
    }
  }
  return any ? arr : h
}

function throwIfError(err) {
  if(err) throw err
}


exports.run = function() {
  "use strict";
  var runCompress = new exports.compressBuild()
  runCompress.deleteExisting()
  .then(runCompress.compressFiles)
  .then(files => {
    console.log('Compression Complete: ')
    const hash = arrToHash(files)
    inspect(hash)
    fs.writeFile(path.join(runCompress.buildPath, "files-list.json"), JSON.stringify(hash), 'utf8', throwIfError)
  })
  .catch(e => {
    console.error(e)
  });
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
