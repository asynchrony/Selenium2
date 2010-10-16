class RubyMappings

  def add_all(fun)
    fun.add_mapping "ruby_library", RubyLibrary.new

    fun.add_mapping "ruby_test", CheckTestArgs.new
    fun.add_mapping "ruby_test", AddTestDefaults.new
    fun.add_mapping "ruby_test", JRubyTest.new
    fun.add_mapping "ruby_test", MRITest.new
    fun.add_mapping "ruby_test", AddTestDependencies.new

    fun.add_mapping "rubydocs", RubyDocs.new
    fun.add_mapping "rubygem",  RubyGem.new
  end

  class RubyLibrary < Tasks

    def handle(fun, dir, args)
      desc "Build #{args[:name]} in build/#{dir}"
      task_name = task_name(dir, args[:name])

      t = task task_name do
        puts "Preparing: #{task_name} in #{build_dir}/#{dir}"
        copy_sources dir, args[:srcs]
        copy_resources dir, args[:resources], build_dir if args[:resources]
        remove_svn_dirs
      end

      add_dependencies t, dir, args[:deps]
      add_dependencies t, dir, args[:resources]
    end

    def copy_sources(dir, globs)
      globs.each do |glob|
        Dir[File.join(dir, glob)].each do |file|
          destination = destination_for(file)
          mkdir_p File.dirname(destination)
          cp file, destination
        end
      end
    end

    def remove_svn_dirs
      Dir["#{build_dir}/rb/**/.svn"].each { |file| rm_rf file }
    end

    def destination_for(file)
      File.join build_dir, file
    end

    def build_dir
      "build"
    end

  end

  class CheckTestArgs
    def handle(fun, dir, args)
      raise "no :srcs specified for #{dir}" unless args.has_key? :srcs
      raise "no :name specified for #{dir}" unless args.has_key? :name
    end
  end

  class AddTestDefaults
    def handle(fun, dir, args)
      args[:include] = Array(args[:include])
      args[:include] << "#{dir}/spec"

      args[:command] = args[:command] || "spec"
      args[:require] = Array(args[:require])

      # move?
      args[:srcs] = args[:srcs].map { |str|
        Dir[File.join(dir, str)]
      }.flatten
    end
  end

  class AddTestDependencies < Tasks
    def handle(fun, dir, args)
      jruby_task = Rake::Task[task_name(dir, "#{args[:name]}-test:jruby")]
      mri_task   = Rake::Task[task_name(dir, "#{args[:name]}-test:mri")]

      # TODO:
      # Specifying a dependency here isn't ideal, but it's the easiest way to
      # avoid a lot of duplication in the build files, since this dep only applies to this task.
      # Maybe add a jruby_dep argument?
      add_dependencies jruby_task, dir, ["//common:test"]

      if args.has_key?(:deps)
        add_dependencies jruby_task, dir, args[:deps]
        add_dependencies mri_task, dir, args[:deps]
      end
    end
  end

  class JRubyTest < Tasks
    def handle(fun, dir, args)
      requires = args[:require] + %w[
        json-jruby.jar
        rubyzip.jar
        childprocess.jar
        ci_reporter.jar
      ].map { |jar| File.join("third_party/jruby", jar) }

      desc "Run ruby tests for #{args[:name]} (jruby)"
      t = task task_name(dir, "#{args[:name]}-test:jruby") do
        puts "Running: #{args[:name]} ruby tests (jruby)"

        ENV['WD_SPEC_DRIVER'] = args[:name]

        # TODO: fix gemfile vs include when jruby-complete.jar understands bundler
        if args[:gemfile]
          args[:include] << args[:gemfile].sub("Gemfile", "lib")
        end

        jruby :include     => args[:include],
              :require     => requires,
              :command     => args[:command],
              :args         => %w[--format CI::Reporter::RSpec],
              :debug       => !!ENV['DEBUG'],
              :files       => args[:srcs]
      end

    end
  end

  class MRITest < Tasks
    def handle(fun, dir, args)
      deps = [args[:gemfile]].compact

      desc "Run ruby tests for #{args[:name]} (mri)"
      task task_name(dir, "#{args[:name]}-test:mri") => deps do
        puts "Running: #{args[:name]} ruby tests (mri)"

        ENV['WD_SPEC_DRIVER'] = args[:name]
        ENV['BUNDLE_GEMFILE'] = args[:gemfile]

        ruby :require => args[:require],
             :include => args[:include],
             :command => args[:command],
             :args    => %w[--format CI::Reporter::RSpec],
             :debug   => !!ENV['DEBUG'],
             :files   => args[:srcs]
      end
    end
  end

  class RubyDocs
    def handle(fun, dir, args)
      if have_yard?
        define_task(dir, args)
      else
        define_noop(dir)
      end
    end

    def define_task(dir, args)
      files      = args[:files] || raise("no :files specified for rubydocs")
      output_dir = args[:output_dir] || raise("no :output_dir specified for rubydocs")

      files  = Array(files).map { |glob| Dir[glob] }.flatten

      YARD::Rake::YardocTask.new("//#{dir}:docs") do |t|
        t.files = args[:files]
        t.options << "--verbose"
        t.options << "--readme" << args[:readme] if args.has_key?(:readme)
        t.options << "--output-dir" << output_dir
      end
    end

    def have_yard?
      require 'yard'
      true
    rescue LoadError
      false
    end

    def define_noop(dir)
      task "//#{dir}:docs" do
        abort "YARD is not available."
      end
    end
  end # RubyDocs

  class RubyGem
    GEMSPEC_HEADER = "# Automatically generated by the build system. Edits may be lost.\n"

    def handle(fun, dir, args)
      raise "no :dir for rubygem" unless args[:dir]
      raise "no :version for rubygem" unless args[:version]

      if has_gem_task?
        define_spec_task      dir, args
        define_clean_task     dir, args
        define_build_task     dir, args
        define_release_task   dir, args
        define_bundler_tasks  dir, args
      end
    end

    def has_gem_task?
      require "rubygems"
      require "rake/gempackagetask"

      true
    rescue LoadError
      false
    end

    def define_spec_task(dir, args)
      gemspec = File.join(args[:dir], "#{args[:name]}.gemspec")

      file gemspec do
        mkdir_p args[:dir]
        Dir.chdir(args[:dir]) {
          File.open("#{args[:name]}.gemspec", "w") { |file|
            file << GEMSPEC_HEADER
            file << gemspec(args).to_ruby
          }
        }
      end

      task("clean_#{gemspec}") { rm_rf gemspec }
    end

    def define_build_task(dir, args)
      gemfile = File.join("build", "#{args[:name]}-#{args[:version]}.gem")
      gemspec = File.join(args[:dir], "#{args[:name]}.gemspec")

      deps = (args[:deps] || [])
      deps << "clean_#{gemspec}" << gemspec

      file gemfile => deps do
        require 'rubygems/builder'
        spec = eval(File.read(gemspec))
        file = Dir.chdir(args[:dir]) {
          Gem::Builder.new(spec).build
        }

        mv File.join(args[:dir], file), gemfile
      end

      desc "Build #{gemfile}"
      task "//#{dir}:gem:build" => gemfile
    end

    def define_clean_task(dir, args)
      desc 'Clean rubygem artifacts'
      task "//#{dir}:gem:clean" do
        rm_rf args[:dir]
        rm_rf "build/*.gem"
      end
    end

    def define_release_task(dir, args)
      desc 'Build and release the ruby gem to Gemcutter'
      task "//#{dir}:gem:release" => %W[//#{dir}:gem:clean //#{dir}:gem:build] do
        sh "gem push build/#{args[:name]}-#{args[:version]}.gem"
      end
    end

    def gemspec(args)
      Gem::Specification.new do |s|
        s.name        = args[:name]
        s.version     = args[:version]
        s.summary     = args[:summary]
        s.description = args[:description]
        s.authors     = args[:author]
        s.email       = args[:email]
        s.homepage    = args[:homepage]
        s.files       = Dir[*args[:files]]

        args[:gemdeps].each { |dep| s.add_dependency(*dep.shift) }
        args[:devdeps].each { |dep| s.add_development_dependency(*dep.shift) }
      end
    end

    def define_bundler_tasks(dir, args)
      gemfile = File.join(args[:dir], "Gemfile")
      gemspec = File.join(args[:dir], "#{args[:name]}.gemspec")

      file(gemfile => gemspec) { create_gemfile(gemfile) }

      desc 'Install dependencies for user/MRI'
      task "//#{dir}:bundle-mri" => gemfile do
        bundle_install :ruby, gemfile
      end

      # desc 'Install dependencies for JRuby'
      # task "//#{dir}:bundle-jruby" do
      #   bundle_install :jruby, gemfile
      # end
    end

    def create_gemfile(file)
      mkdir_p File.dirname(file)
      File.open(file, "w") { |file|
        file << "source :rubygems\ngemspec\n"
      }
    end

    def bundle_install(ruby, file)
      args = ["install", "--gemfile", file]
      args += ["--path", ENV['BUNDLE_PATH']] if ENV['BUNDLE_PATH']

      RubyRunner.run ruby,
        :command => "bundle",
        :args    => args
    end

  end # RubyGem
end # RubyMappings

class RubyRunner

  JRUBY_JAR = "third_party/jruby/jruby-complete.jar"

  def self.run(impl, opts)
    cmd = ["ruby"]

    if impl.to_sym == :jruby
      JRuby.runtime.instance_config.run_ruby_in_process = true
      cmd << "-J-Djava.awt.headless=true" if opts[:headless]
    else
      JRuby.runtime.instance_config.run_ruby_in_process = false
    end

    if opts[:debug]
      cmd << "-d"
    end

    if opts.has_key? :include
      cmd << "-I"
      cmd << Array(opts[:include]).join(File::PATH_SEPARATOR)
    end

    Array(opts[:require]).each do |f|
      cmd << "-r#{f}"
    end

    cmd << "-S" << opts[:command] if opts.has_key? :command
    cmd += Array(opts[:args]) if opts.has_key? :args
    cmd += Array(opts[:files]) if opts.has_key? :files

    puts cmd.join(' ')

    sh(*cmd)
  end
end

def jruby(opts)
  RubyRunner.run :jruby, opts
end

def ruby(opts)
  RubyRunner.run :ruby, opts
end
