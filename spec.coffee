{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

gulpsmith = require './'
{to_metal, to_vinyl} = gulpsmith
fs = require 'fs'
{resolve, sep:pathsep} = require('path')
File = require 'vinyl'
_ = require 'highland'
Metalsmith = require 'metalsmith'

expect_fn = (item) -> expect(item).to.exist.and.be.a('function')
{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

compare_gulp = (infiles, transform, outfiles, done) ->
    _(file for own path, file of infiles)
    .pipe(transform).toArray (files) ->
        transformed = {}
        for file in files
            transformed[file.relative] = file
        transformed.should.eql outfiles
        done()

compare_metal = (infiles, smith, outfiles, done) ->
    smith.run infiles, (err, transformed) ->
        if err
            done(err)
        else
            transformed.should.eql outfiles
            done()

check_mode = (vinylmode, metalmode) ->
    (vinylmode).should.equal parseInt(metalmode, 8)


describe "Metal -> Vinyl Conversion", ->

    mf = mystat = null
    beforeEach ->
        mystat = fs.statSync('README.md')
        mf = contents: Buffer(''), mode: (mystat.mode).toString(8)
    
    it "assigns a correct relative path", ->
        to_vinyl("path1", mf).relative.should.equal "path1"
        to_vinyl("README.src", mf).relative.should.equal "README.src"

    it "converts Metalsmith .mode to Gulp .stat", ->
        check_mode to_vinyl("README.md", mf).stat.mode, mf.mode        
        mf.mode = (~parseInt(mf.mode, 8)).toString(8)
        check_mode to_vinyl("README.md", mf).stat.mode, mf.mode

    it "removes the Metalsmith.mode", ->
        expect(to_vinyl("README.md", mf).mode).not.to.exist

    it "assigns Metalsmith .contents to Gulp .contents", ->
        to_vinyl("xyz", mf).contents.should.equal mf.contents
        mf.contents = Buffer("blah blah blah")
        to_vinyl("abc", mf).contents.should.eql Buffer("blah blah blah")

    it "adds .cwd and .base to files (w/Metalsmith instance given)", ->
        verify = (smith) ->
            vf = to_vinyl("mnop", mf, smith)
            vf.base.should.equal smith.source()
            vf.cwd.should.equal smith.join()
        verify smith = Metalsmith "/foo/bar"
        verify smith.source "spoon"
        verify Metalsmith __dirname









    it "copies arbitrary attributes (exactly)", ->
        verify = new File(
            base: __dirname, cwd: __dirname, stat: mystat, path:resolve "README.md"
        )
        mf.x = verify.x = 1
        mf.y = verify.y = z: 2
        res = to_vinyl("README.md", mf)
        delete mf.contents
        delete res._contents
        delete verify._contents
        delete res.stat
        delete verify.stat
        res.should.eql verify        

    it "doesn't overwrite the .relative property on Vinyl files", ->
        mf.relative = "ping!"
        to_vinyl("pong/whiz", mf, Metalsmith __dirname)
        .relative.should.equal "pong#{pathsep}whiz"

    it "doesn't overwrite any ``vinyl`` methods or properties", ->
        for own name of (File::)
            mf[name] = "bad data for .#{name}"
        for own name of new File()
            mf[name] = "bad data for .#{name}"
        vf = to_vinyl("what/ever", mf, Metalsmith __dirname)
        for own name, prop of (File::)
            expect(vf[name]).to.equal prop
        for own name of vf
            expect(vf[name]).to.not.equal "bad data for .#{name}"












describe "Vinyl -> Metal Conversion", ->
    gf = null
    beforeEach -> gf = new File(
        path: "README.md", contents: Buffer(''), stat: fs.statSync('README.md')
    )
    
    it "throws an error for non-buffered (empty or stream) files", ->
        expect(
            -> to_metal new File(path:"foo.bar")
        ).to.throw /foo\.bar/
        expect(
            -> to_metal new File(path:"spam.baz",
                contents: fs.createReadStream('README.md')
        )).to.throw /spam\.baz/

    it "converts Gulp .stat to Metalsmith .mode", ->
        (parseInt(to_metal(gf).mode, 8)).should.equal gf.stat.mode & 4095
        gf.stat.mode = ~gf.stat.mode
        (parseInt(to_metal(gf).mode, 8)).should.equal gf.stat.mode & 4095

    it "assigns Gulp .contents to Metalsmith .contents", ->
        to_metal(gf).contents.should.equal gf.contents
        gf.contents = Buffer("blah blah blah")
        to_metal(gf).contents.should.eql Buffer("blah blah blah")

    it "copies arbitrary attributes (exactly)", ->
        verify =
            x: 1, y: z:2
        gf.x = 1
        gf.y = z: 2
        res = to_metal(gf)
        delete gf.contents
        delete res.contents
        delete res.mode
        res.should.eql verify        

    it "doesn't keep any ``vinyl`` methods or properties", ->
        to_metal(gf).should.not.have.property name for own name of (File::)
        to_metal(gf).should.not.have.property name for own name of gf            
        to_metal(gf).should.not.have.property "relative"

describe "gulpsmith() streams", ->

    s = testfiles = null
    beforeEach -> s = gulpsmith()

    null_plugin = (files, smith, done) -> done()

    describe ".use() method", ->
        plugin1 = spy.named "plugin1", null_plugin
        plugin2 = spy.named "plugin2", null_plugin
        it "returns self", -> expect(s.use(plugin1)).to.equal s
        it "invokes passed plugins during build", (done) ->
            s.use(plugin1).use(plugin2)
            _([]).pipe(s).toArray ->
                plugin1.should.be.calledOnce.and.calledBefore plugin2
                plugin2.should.be.calledOnce.and.calledAfter plugin1
                done()

    describe ".metadata() method", ->
        data = {a: 1, b:2}
        it "returns self when setting", ->
            expect(s.metadata(data)).to.equal s

        it "returns matching metadata when getting", ->
            s.metadata(data)
            expect(s.metadata()).to.eql data















    describe "streaming", ->

        beforeEach ->
            testfiles =
                f1: new File(path:resolve("f1"), contents:Buffer('f1'))
                f2: new File(path:resolve("f2"), contents:Buffer('f2'))
            testfiles.f1.a = "b"
            testfiles.f2.c = 3
    
        it "should yield the same files (if no plugins)", (done) ->
            compare_gulp testfiles, s, testfiles, done

        it "should delete files deleted by a Metalsmith plugin", (done) -> 
            s.use (f,s,d) -> delete f.f1; d()
            compare_gulp testfiles, s, {f2:testfiles.f2}, done

        it "should add files added by a Metalsmith plugin", (done) -> 
            s.use (files, smith, done) ->
                files.f3 = contents:Buffer "f3"
                done()
            compare_gulp(
                {}, s, f3: new File(
                    path:resolve("f3"), base:__dirname, contents:Buffer "f3"
                ), done
            )

        it "yields errors for non-buffered files (and continues)", (done) ->
            testfiles.f1.contents = null
            done = should_error done, /buffered.*f1/
            compare_gulp testfiles, s, {f2:testfiles.f2},
                -> done new Error "No error caught"

        it "yields errors for errors produced by Metalsmith plugins", (done) ->
            error_message = "demo error!" 
            s.use (files, smith, d) -> d new Error(error_message)
            done = should_error done, error_message
            _([]).pipe(s).toArray -> done Error "Error wasn't caught"




        it "excludes Gulp directories", (done) ->
            testfiles.f2.isDirectory = -> true
            compare_gulp testfiles, s, {f1:testfiles.f1}, done

        it "converts Gulp files to Metalsmith and back", (done) ->

            vinyl_spy = spy.named 'vinyl_spy', gulpsmith, 'to_vinyl'
            metal_spy = spy.named 'metal_spy', gulpsmith, 'to_metal'
            err = metal_files = null

            # Capture files coming into Metalsmith
            catch_metal = (files, smith, done) ->
                metal_files = files
                done()

            _(file for own path, file of testfiles)
            .pipe(gulpsmith().use(catch_metal)).toArray (files) ->
                try
                    for file in files
                        vinyl_spy.should.have.returned file
                        metal_spy.should.have.been.calledWithExactly file

                    for own relative, file of metal_files
                        vinyl_spy.should.have.been
                        .calledWithExactly relative, file

                        metal_spy.should.have.returned file
                catch err
                    return done(err)
                finally
                    vinyl_spy.restore()
                    metal_spy.restore()
                done()








        should_error = (done, ematch, etype=Error) ->

            s.on "error", (e) ->
                try
                    e.should.be.instanceOf Error
                    if ematch?
                        if ematch instanceof RegExp
                            e.message.should.match ematch
                        else
                            e.message.should.equal ematch
                    cb()
                catch err
                    cb(err)

            return cb = ->
                done arguments...
                done = ->
























describe "gulpsmith.pipe() plugins", ->

    smith = testfiles = null

    it "are functions", ->
        expect(gulpsmith.pipe()).to.be.a('function')

    describe ".pipe() method", ->
        it "is a function", -> expect(gulpsmith.pipe().pipe).to.exist.and.be.a('function')
        it "returns a function with another pipe() method", ->
            expect(gulpsmith.pipe().pipe().pipe).to.exist.and.be.a('function')

    describe "streaming", ->

        beforeEach ->
            smith = Metalsmith(process.cwd())
            testfiles =
                f1: contents:Buffer('f1')
                f2: contents:Buffer('f2')
            testfiles.f1.a = "b"
            testfiles.f2.c = 3
    
        it "should yield the same files (if no plugins)", (done) ->
            compare_metal testfiles, smith.use(gulpsmith.pipe()), testfiles, done

        it "should delete files deleted by a Gulp plugin", (done) -> 
            s = smith.use gulpsmith.pipe _.where relative: 'f2'
            compare_metal testfiles, s, {f2:testfiles.f2}, done

        it "should add files added by a Gulp plugin", (done) ->
            f3 = new File path: "f3", contents:Buffer "f3"
            f3.x = "y"; f3.z = 42
            s = smith.use gulpsmith.pipe(_.append f3)
            compare_metal {}, s, {f3:  {
                x: "y", z:42, contents:Buffer "f3"
            }}, done





        it "converts Metalsmith files to Gulp and back", (done) ->

            vinyl_spy = spy.named 'vinyl_spy', gulpsmith, 'to_vinyl'
            metal_spy = spy.named 'metal_spy', gulpsmith, 'to_metal'
            vinyl_files = []
        
            # Capture files coming into Gulp
            catch_vinyl = (file) ->
                vinyl_files.push file
                return file

            smith = Metalsmith(__dirname)
            smith.use(gulpsmith.pipe((_.map catch_vinyl)))

            smith.run testfiles, (err, files) ->
                return done(err) if err?
                try
                    for file in vinyl_files
                        vinyl_spy.should.have.returned file
                        metal_spy.should.have.been.calledWithExactly file

                    for own relative, file of files
                        vinyl_spy.should.have.been
                        .calledWithExactly relative, file, smith
                        metal_spy.should.have.returned file
                catch err
                    return done(err)
                finally
                    vinyl_spy.restore()
                    metal_spy.restore()
                done()
            
        it "exits with any error yielded by a Gulp plugin", (done) ->
            message = "dummy error!"
            smith.use gulpsmith.pipe _ (push) ->
                push new Error message
                push null, _.nil

            done = should_error done, {}, message


        it "exits with an error if a Gulp plugin yields an unbuffered file",
        (done) ->
            smith.use gulpsmith.pipe _.append new File(path: "README.md")
            done = should_error done, {}, /buffered.*README.md/

        should_error = (done, files, ematch, etype=Error) ->

            smith.run files, (e, files) ->
                try
                    e.should.be.instanceOf Error
                    if ematch?
                        if ematch instanceof RegExp
                            e.message.should.match ematch
                        else
                            e.message.should.equal ematch
                    cb()
                catch err
                    cb(err)

            return cb = ->
                done arguments...
                done = ->



















