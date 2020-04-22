const workboxBuild = require('workbox-build');

// Do this as the first thing so that any code reading it knows the right env.
process.env.BABEL_ENV = 'production';
process.env.NODE_ENV = 'production';
process.on('unhandledRejection', err => {
  console.log(err, err.stack)
  throw err;
});

require('./config/env');

const path = require('path');
const fs = require('fs-extra');
const paths = require('./config/paths');

// NOTE: This should be run *AFTER* all your assets are built
exports.inject = () => new Promise(r => {
                      try {
                        fs.removeSync(path.resolve(paths.appBuild, 'sw-asset-manifest.json'));
                      } catch(_) {}
                      try {
                        fs.removeSync(path.resolve(paths.appBuild, 'service-worker.js'));
                      } catch(_) {}
                      try {
                        fs.removeSync(path.resolve(paths.appBuild, 'service-worker.js.map'));
                      } catch(_) {}
                      r()
                    })
                    .then(
                      () => workboxBuild.injectManifest({
                              swSrc: paths.appWorkboxSwJs, // this is your sw template file
                              swDest: paths.appSwJs, // this will be created in the build step
                              globDirectory: paths.appBuild,
                              globPatterns: [
                                '**\/*.{js,css,html,png}',
                              ]
                            })
                    )
                    .then(({count, size, warnings}) => {
                      // Optionally, log any warnings and details.
                      warnings.forEach(console.warn);
                      console.log(`${count} files will be precached, totaling ${size} bytes.`);
                    });


exports.compile = () => {

  const chalk = require('chalk');
  const webpack = require('webpack');
  const config = require('./config/webpack.config');
  const checkRequiredFiles = require('react-dev-utils/checkRequiredFiles');
  const formatWebpackMessages = require('react-dev-utils/formatWebpackMessages');
  const printHostingInstructions = require('react-dev-utils/printHostingInstructions');
  const FileSizeReporter = require('react-dev-utils/FileSizeReporter');
  const printBuildError = require('react-dev-utils/printBuildError');

  const measureFileSizesBeforeBuild =
    FileSizeReporter.measureFileSizesBeforeBuild;
  const printFileSizesAfterBuild = FileSizeReporter.printFileSizesAfterBuild;
  const useYarn = fs.existsSync(paths.yarnLockFile);

  // These sizes are pretty large. We'll warn for bundles exceeding them.
  const WARN_AFTER_BUNDLE_GZIP_SIZE = 512 * 1024;
  const WARN_AFTER_CHUNK_GZIP_SIZE = 1024 * 1024;

  // Warn and crash if required files are missing
  if (!checkRequiredFiles([paths.appSwJs])) {
    process.exit(1);
  }

  // Create the production build and print the deployment instructions.
  function buildCurrentSW(previousFileSizes) {
    console.log('Building Service Worker');

    let compiler = webpack(config);
    return new Promise((resolve, reject) => {
      compiler.run((err, stats) => {
        if (err) {
          return reject(err);
        }
        const messages = formatWebpackMessages(stats.toJson({}, true));
        if (messages.errors.length) {
          // Only keep the first error. Others are often indicative
          // of the same problem, but confuse the reader with noise.
          if (messages.errors.length > 1) {
            messages.errors.length = 1;
          }
          return reject(new Error(messages.errors.join('\n\n')));
        }
        if (
          process.env.CI &&
          (typeof process.env.CI !== 'string' ||
            process.env.CI.toLowerCase() !== 'false') &&
          messages.warnings.length
        ) {
          console.log(
            chalk.yellow(
              '\nTreating warnings as errors because process.env.CI = true.\n' +
                'Most CI servers set it automatically.\n'
            )
          );
          return reject(new Error(messages.warnings.join('\n\n')));
        }

        return resolve({
          stats,
          previousFileSizes,
          warnings: messages.warnings,
        });
      });
    });
  }

  // First, read the current file sizes in build directory.
  // This lets us display how much they changed later.
  return measureFileSizesBeforeBuild(paths.appBuild)
    .then(buildCurrentSW)
    .then(
      ({ stats, previousFileSizes, warnings }) => {
        if (warnings.length) {
          console.log(chalk.yellow('Compiled with warnings.\n'));
          console.log(warnings.join('\n\n'));
          console.log(
            '\nSearch for the ' +
              chalk.underline(chalk.yellow('keywords')) +
              ' to learn more about each warning.'
          );
          console.log(
            'To ignore, add ' +
              chalk.cyan('// eslint-disable-next-line') +
              ' to the line before.\n'
          );
        } else {
          console.log(chalk.green('Compiled successfully.\n'));
        }

        console.log('File sizes after gzip:\n');

        printFileSizesAfterBuild(
          stats,
          previousFileSizes,
          paths.appBuild,
          WARN_AFTER_BUNDLE_GZIP_SIZE,
          WARN_AFTER_CHUNK_GZIP_SIZE
        );

        const appPackage = require(paths.appPackageJson);
        const publicUrl = paths.publicUrl;
        const publicPath = config.output.publicPath;
        const buildFolder = path.relative(process.cwd(), paths.appBuild);

        return printHostingInstructions(
          appPackage,
          publicUrl,
          publicPath,
          buildFolder,
          useYarn
        );
      },
      err => {
        console.log(chalk.red('Failed to compile.\n'));
        printBuildError(err);
        process.exit(1);
      }
    );
};

exports.run = () => {
  exports.inject().then(exports.compile).then(exports.copy);
};

exports.copy = () => new Promise(res => {
  try {
    fs.copySync(path.resolve(paths.appBuild, 'service-worker.js'), path.resolve(paths.appPublic, 'service-worker.js'))
    fs.copySync(path.resolve(paths.appBuild, 'sw-asset-manifest.json'), path.resolve(paths.appPublic, 'sw-asset-manifest.json'));
  } catch(_) {}

  res()
});

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
