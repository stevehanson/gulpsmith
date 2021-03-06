(function() {
  var File, clone_stats, gulp_stream, gulpsmith, highland, make_pipe, metal_plugin, reserved_names, resolve,
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty;

  module.exports = gulpsmith = function(dir) {
    var smith, stream;
    if (dir == null) {
      dir = process.cwd();
    }
    stream = gulp_stream(smith = require("metalsmith")(dir));
    stream.src = function(sourceDir) {
      smith.source(sourceDir);
      return this;
    };
    stream.use = function(plugin) {
      smith.use(plugin);
      return this;
    };
    stream.metadata = function() {
      if (!arguments.length) {
        return smith.metadata();
      }
      smith.metadata.apply(smith, arguments);
      return this;
    };
    return stream;
  };

  gulpsmith.pipe = make_pipe = function() {
    var pipeline, plugin;
    pipeline = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    plugin = metal_plugin(pipeline);
    plugin.pipe = function() {
      var streams;
      streams = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return make_pipe.apply(null, __slice.call(pipeline).concat(__slice.call(streams)));
    };
    return plugin;
  };

  highland = require('highland');

  File = require('vinyl');

  clone_stats = require('clone-stats');

  resolve = require('path').resolve;

  metal_plugin = function(streams) {
    return function(files, smith, done) {
      var error, error_handler, file, path, pipeline;
      pipeline = highland.pipeline.apply(highland, streams);
      error = null;
      pipeline.on("error", error_handler = function(e) {
        if (error == null) {
          done(error = e);
        }
      });
      pipeline.toArray(function(fileArray) {
        var e, file, outfiles, path, _i, _len;
        outfiles = {};
        for (_i = 0, _len = fileArray.length; _i < _len; _i++) {
          file = fileArray[_i];
          try {
            outfiles[file.relative] = gulpsmith.to_metal(file);
          } catch (_error) {
            e = _error;
            return error_handler(e);
          }
        }
        for (path in files) {
          if (!__hasProp.call(files, path)) continue;
          if (!outfiles.hasOwnProperty(path)) {
            delete files[path];
          }
        }
        for (path in outfiles) {
          if (!__hasProp.call(outfiles, path)) continue;
          file = outfiles[path];
          files[path] = file;
        }
        if (error == null) {
          return done();
        }
      });
      for (path in files) {
        if (!__hasProp.call(files, path)) continue;
        file = files[path];
        pipeline.write(gulpsmith.to_vinyl(path, file, smith));
        if (error != null) {
          break;
        }
      }
      return pipeline.end();
    };
  };

  gulp_stream = function(smith) {
    var pipeline;
    return pipeline = highland.pipeline(function(stream) {
      stream = stream.reduce({}, function(files, file) {
        var err;
        if (!file.isDirectory()) {
          try {
            files[file.relative] = gulpsmith.to_metal(file);
          } catch (_error) {
            err = _error;
            pipeline.emit('error', err);
          }
        }
        return files;
      });
      return stream.flatMap(function(files) {
        return highland(function(push, next) {
          return smith.run(files, function(err, files) {
            var file, relative;
            if (err) {
              push(err);
              next([]);
            } else {
              next((function() {
                var _results;
                _results = [];
                for (relative in files) {
                  if (!__hasProp.call(files, relative)) continue;
                  file = files[relative];
                  _results.push(gulpsmith.to_vinyl(relative, file));
                }
                return _results;
              })());
            }
          });
        });
      });
    });
  };

  reserved_names = Object.create(null, {
    path: {
      value: true
    },
    cwd: {
      value: true
    },
    base: {
      value: true
    },
    _contents: {
      value: true
    },
    mode: {
      value: true
    },
    stat: {
      value: true
    }
  });

  (function() {
    var _i, _len, _prop, _ref, _results;
    _ref = Object.getOwnPropertyNames(File.prototype);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _prop = _ref[_i];
      _results.push(reserved_names[_prop] = true);
    }
    return _results;
  })();

  gulpsmith.to_metal = function(vinyl_file) {
    var key, metal_file, val, _ref;
    if (!vinyl_file.isBuffer()) {
      throw new Error("Metalsmith needs buffered files: " + vinyl_file.relative);
    }
    metal_file = {};
    for (key in vinyl_file) {
      if (!__hasProp.call(vinyl_file, key)) continue;
      val = vinyl_file[key];
      if (!(key in reserved_names)) {
        metal_file[key] = val;
      }
    }
    metal_file.contents = vinyl_file.contents;
    if (((_ref = vinyl_file.stat) != null ? _ref.mode : void 0) != null) {
      metal_file.mode = ('0000' + (vinyl_file.stat.mode & 4095).toString(8)).slice(-4);
    }
    return metal_file;
  };

  gulpsmith.to_vinyl = function(relative, metal_file, smith) {
    var key, opts, val, vinyl_file;
    opts = Object.create(metal_file);
    if (smith != null) {
      opts.cwd = smith.join();
      opts.base = smith.source();
    } else {
      opts.cwd = process.cwd();
      opts.base = opts.cwd;
    }
    opts.path = resolve(opts.base, relative);
    if (opts.mode != null) {
      opts.stat = clone_stats({
        mode: parseInt(opts.mode, 8)
      });
    }
    vinyl_file = new File(opts);
    for (key in metal_file) {
      if (!__hasProp.call(metal_file, key)) continue;
      val = metal_file[key];
      if (!(key in reserved_names)) {
        vinyl_file[key] = val;
      }
    }
    return vinyl_file;
  };

}).call(this);
