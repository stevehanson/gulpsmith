# The ``gulpsmith`` API

The ``gulpsmith()`` function exported by this module accepts a single, optional
argument: a directory name that defaults to ``process.cwd()``.  The return
value is a stream (aka "Gulp plugin") wrapping a ``Metalsmith`` instance.

    module.exports = gulpsmith = (dir = process.cwd()) ->

        stream = gulp_stream(smith = require("metalsmith")(dir))

The returned stream gets ``.use()`` and ``.metadata()`` methods that delegate
to the underlying Metalsmith instance, but return the stream instead of the
Metalsmith instance.  (Calling ``.metadata()`` with no arguments returns the
metadata, however.)

        stream.use = (plugin) ->
            smith.use(plugin)
            return this

        stream.metadata = ->
            if !arguments.length
                return smith.metadata()
            smith.metadata(arguments...)
            return this

        return stream

``gulpsmith.pipe()``, on the other hand, accepts one or more streams to be
wrapped for use as a Metalsmith plugin, and returns a plugin function with a
``.pipe()`` method for extending the pipeline:

    gulpsmith.pipe = make_pipe = (pipeline...) ->
        plugin = metal_plugin(pipeline)
        plugin.pipe = (streams...) -> make_pipe(pipeline..., streams...)
        return plugin






Both conversion directions use ``highland`` streams, require conversions
to/from ``vinyl`` File objects, and do mode/stats translations (via
``clone-stats``).

    highland = require 'highland'
    File = require 'vinyl'
    clone_stats = require 'clone-stats'

### Table of Contents

<!-- toc -->

* [Wrapping A Gulp Pipeline as a Metalsmith Plugin](#wrapping-a-gulp-pipeline-as-a-metalsmith-plugin)
* [Wrapping Metalsmith as a Gulp Plugin](#wrapping-metalsmith-as-a-gulp-plugin)
* [File Conversions](#file-conversions)
  * [``vinyl`` Files To Metalsmith Files](#vinyl-files-to-metalsmith-files)
  * [Metalsmith Files To ``vinyl`` Files](#metalsmith-files-to-vinyl-files)

<!-- toc stop -->






















## Wrapping A Gulp Pipeline as a Metalsmith Plugin

A ``gulpsmith.pipe()`` plugin is a function that runs Metalsmith's files
through a Gulp pipeline back into Metalsmith.

    metal_plugin = (streams) -> (files, smith, done) ->

        pipeline = highland.pipeline(streams...)

To handle errors, we define an error handler that can be invoked at most once.
It works by passing the error on to the next step in the Metalsmith plugin
chain (or ``run()/build()`` error handler).  It saves the error, so that other
parts of the plugin know not to keep processing files afterwards, and not to
call ``done()`` a second time.

        error = null

        pipeline.on "error", error_handler = (e) ->
            if !error?
                done error = e
            return
        
Each file received from the Gulp pipeline is converted to a Metalsmith file and
stored in a map for sending back to Metalsmith.

        pipeline.toArray (fileArray) ->

            outfiles = {}
            for file in fileArray
                try outfiles[file.path] = to_metal(file)
                catch e then return error_handler(e)

Assuming no errors occurred, we delete from Metalsmith's files any files
that were dropped (or renamed) in the Gulp pipeline.  Then we add any new or
renamed files (and/or overwrite the modified ones), and tell Metalsmith we
finished without errors.

            for own path of files
                if not outfiles.hasOwnProperty path
                    delete files[path]

            for own path, file of outfiles
                files[path] = file

            done() unless error?

Now that the pipeline is ready, we can push our converted versions of all the
Metalsmith files into its head end (stopping if an error happens at any point).

        for own path, file of files
            pipeline.write to_vinyl(path, file, smith)
            break if error?

        pipeline.end()




























## Wrapping Metalsmith as a Gulp Plugin

The result of wrapping a Metalsmith instance as a Gulp plugin is a ``highland``
pipeline with a couple of Metalsmith wrapper methods.

All the pipeline really does at first is accumulate Gulp file objects and
convert them to Metalsmith file objects.  If an error occurs in the conversion,
an error event is emitted at the output end of the pipeline, and the file is
skipped.

    gulp_stream = (smith) -> pipeline = highland.pipeline (stream) ->

        stream = stream.reduce {}, (files, file) ->
            try
                files[file.path] = to_metal(file)
            catch err
                pipeline.emit 'error', err
            return files

Once all the files have arrived, we run them through our Metalsmith's ``run()``
method, converting any Metalsmith error into an ``error`` event on the
pipeline.  If no errors happened, we simply stream out the converted files to
the next step in the overall Gulp pipeline flow.  Either way, the pipeline's
output is ended afterwards.

        return stream.flatMap (files) -> highland (push, next) ->

            smith.run files, (err, files) ->
                if err
                    push(err)
                    next([])
                else
                    next(to_vinyl(path, file) for own path, file of files)
                return







## File Conversions

Metalsmith and gulp use almost, but not quite, *completely different*
conventions for their file objects.  Gulp uses ``vinyl`` instances, which know
their own path information, and Metalsmith uses plain objects with a
``contents`` buffer, that intentionally do *not* know their own path info.

Basically, the ``contents`` buffer attribute is the *only* thing they have in
common, and even there, Metalsmith uses a plain property that's always a
``Buffer``, while ``vinyl`` objects use a getter property that wraps a
private``_contents`` attribute that can be a stream or null!

Both kinds of files can have more-or-less arbitrary metadata attributes, but in
Metalsmith's case these are read from files' YAML "front matter", whereas
gulp's can come from any plugin, and e.g. the ``gulp-front-matter`` plugin adds
front-matter data to a single ``frontMatter`` property by default.

In short, there is no single, simple, canonical transformation possible *in
either direction*, only some general guidelines and heuristics.






















### ``vinyl`` Files To Metalsmith Files

Because ``vinyl`` files can be empty or streamed instead of buffered,
``to_metal()`` raises an error if its argument isn't buffered.

    to_metal = (vinyl_file) ->

        if not vinyl_file.isBuffer()
            throw new Error("Metalsmith needs buffered files: #{vinyl_file.path}")

The ``vinyl`` file's attributes are copied, skipping path information,
any ``.metalsmith`` attribute, and the internal ``_contents`` attribute.  (The
path attribute needs to be removed because it can become stale as the file is
processed by Metalsmith plugins, and the contents are transferred separately
along with a conversion from vinyl's ``stat`` to Metalsmith's ``mode``.)

        metal_file = {}
        for own key, val of vinyl_file
            unless key is "path" or key is "metalsmith" or key is "_contents"
                metal_file[key] = val

        metal_file.contents = vinyl_file.contents
        metal_file.mode = vinyl_file.stat.mode if vinyl_file.stat?.mode?
        return metal_file

















### Metalsmith Files To ``vinyl`` Files

Since Metalsmith files don't know their own path, ``to_vinyl()`` needs a path
as well as the file object, and an optional ``Metalsmith`` instance.

    to_vinyl = (path, metal_file, smith) ->

        opts = Object.create metal_file
        opts.path = path

In addition to a path, ``vinyl`` files need a ``cwd``, and ``base`` in order to
function properly.  If these properties aren't on the input file, we can
simulate them if a ``Metalsmith`` instance is available.  (By assuming that
Metalsmith file paths are relative to Metalsmith's source path.)

        if smith?
            opts.cwd ?= smith.join()
            opts.base ?= smith.source()

The rest is just copying attributes and converting Metalsmith's ``mode`` to a
``vinyl`` ``stat``, if needed.  We skip any ``relative`` property because
that's not writable on ``vinyl`` files, and we optionally add a ``metalsmith``
property for the convenience of Gulp plugins being used inside a Metalsmith
pipeline.

        if opts.mode?
            opts.stat = clone_stats mode: opts.mode

        vinyl_file = new File opts

        for own key, val of metal_file
            vinyl_file[key] = val # XXX unless key is "relative"

        vinyl_file.metalsmith = smith if smith?
        return vinyl_file





