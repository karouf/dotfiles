#!/usr/bin/env ruby

require "json"
require "yaml"

module Homestage
  class ConfigParser
    def self.parse_config_item(config, key, klass)
      if config[key]
        config[key].map { |c| klass.parse(c) }
      else
        []
      end
    end
  end

  class Config < ConfigParser
    OUTPUT_FORMATS = %i[json toml yaml]

    attr_accessor :variables, :profiles

    def self.parse(file_path)
      config_file = YAML.load(File.read(file_path))

      raise InvalidConfig unless valid_config?(config_file)

      config = Config.new
      config.variables = parse_config_item(config_file, "variables", Variable)
      config.profiles = parse_config_item(config_file, "profiles", Profile)
      config
    end

    def to_homemaker(format)
      raise UnsupportedFormat unless OUTPUT_FORMATS.include? format

      homemaker_tasks = {}
      homemaker_tasks["default"] = default_task
      homemaker_tasks["config_variables"] = config_variables_task

      profiles.each do |profile|
        homemaker_tasks.merge!(profile.to_homemaker)
      end
      
      homemaker_config = { "tasks" => homemaker_tasks, "macros" => homemaker_macros }

      case format
      when :json
        homemaker_config.to_json
      when :toml
        raise "TOML output format not supported yet!"
      when :yaml
        homemaker_config.to_yaml
      end
    end

    def leaf_profiles
      reverse_dependencies = {}

      profiles.each do |profile|
        reverse_dependencies[profile.name] ||= []

        profile.dependencies.each do |dependency|
          reverse_dependencies[dependency.name] ||= []
          reverse_dependencies[dependency.name] << profile.name
        end
      end

      reverse_dependencies.select { |name, reqs| reqs.empty? }.map { |name, reqs| name }
    end

    def used_profiles_for(profile)
      profiles = [profile]

      profile.dependencies.map { |d| self.profiles.find { |p| p.name == d.name } }.each do |dependency|
        profiles << dependency
        profiles += used_profiles_for(dependency)
      end

      profiles.uniq
    end

    private

    def self.valid_config?(file)
      # check unicity of profiles
      # check dependency graph is acyclic
      # check unicity of packages, links and templates for each leaf profile and its dependencies
      file["profiles"] ? true : false
    end

    def default_task
      { "deps" => ["common"] }
    end

    def config_variables_task
      env_vars = variables.map { |var| [var.name, var.value] }
      { "envs" => env_vars }
    end

    def homemaker_macros
      { "install" => { "prefix" => ["sudo", "apt", "install", "-yqq"] } }
    end
  end

  class Variable
    attr_reader :name, :value

    def self.parse(config)
      Variable.new(name: config.first, value: config.last)
    end

    def initialize(name:, value: )
      @name = name
      @value = value
    end
  end

  class Profile < ConfigParser
    attr_reader :name
    attr_accessor :dependencies, :packages, :roles

    def self.parse(config)
      profile = Profile.new(config.first)

      config = config.last

      profile.dependencies = parse_config_item(config, "dependencies", Dependency)
      profile.packages = parse_config_item(config, "packages", Package)
      profile.roles = parse_config_item(config, "roles", Role)
      profile
    end

    def initialize(name)
      @name = name
    end

    def to_homemaker
      tasks = {}

      tasks[name] = to_task

      packages.each do |package|
        unless tasks["#{name}_#{package.name}"]
          tasks.merge!(package.to_homemaker(self))
        end
      end

      tasks
    end

    private

    def to_task
      profile_deps = dependencies.map { |d| d.name }
      package_deps = packages.map { |p| "#{name}_#{p.name}" }

      { "deps" => profile_deps + package_deps }
    end
  end

  class Package < ConfigParser

    attr_reader :name
    attr_accessor :commands, :links, :templates

    def self.parse(config)
      case config.class.to_s
      when "String"
        Package.new(config)
      when "Array"
        package = Package.new(config.first)

        config = config.last

        package.commands = parse_config_item(config, "commands", Command)
        package.links = config["links"].map { |c| Link.parse(c) } if config["links"]
        package.templates = config["templates"].map { |c| Template.parse(c) } if config["templates"]
        package
      else
        raise InvalidConfig, "Invalid package config: #{config}"
      end
    end

    def initialize(name)
      @name = name
      @commands = []
      @links = []
      @templates = []
    end

    def to_homemaker(profile)
      task = {
        "#{profile.name}_#{name}" => { "deps" => [
          "#{profile.name}_#{name}_install",
          "#{profile.name}_#{name}_config",
        ] },
        "#{profile.name}_#{name}_install" => { "cmds" => [["@install", name]] },
        "#{profile.name}_#{name}_config" => {
          "cmds" => commands.map { |c| c.to_homemaker },
          # handle path to files: <profile>/<package>/<file> linked to <file> in $HOME
          "links" => links.map { |l| [l.path, "profiles/#{profile.name}/#{name}/#{l.path}"] },
          "templates" => templates.map { |t| [t.path, "profiles/#{profile.name}/#{name}/#{t.path}"] },
        }
      }

      task["#{profile.name}_#{name}_config"]["deps"] = ["config_variables"] if templates

      task
    end
  end

  class Dependency
    attr_reader :name

    def self.parse(config)
      Dependency.new(config)
    end

    def initialize(name)
      @name = name
    end
  end

  class Role
    attr_reader :name

    def self.parse(config)
      Role.new(config)
    end

    def initialize(name)
      @name = name
    end
  end

  class Command
    attr_reader :line

    def self.parse(config)
      Command.new(config)
    end

    def initialize(line)
      @line = line
    end

    def to_homemaker
      ["sh", "-c", line]
    end
  end

  class Link
    attr_reader :path

    def self.parse(config)
      Link.new(config)
    end

    def initialize(path)
      @path = path
    end
  end

  class Template
    attr_reader :path

    def self.parse(config)
      Template.new(config)
    end

    def initialize(path)
      @path = path
    end
  end
    
  class InvalidConfig < RuntimeError; end
end

def usage
  puts "homestage.rb <action>"
  puts
  puts "Actions:"
  puts "  do <profile>    apply given profile"
  puts "  help            display this message"
  puts "  list            list available profiles"
end

config = Homestage::Config.parse("profiles.yml")

action = ARGV.shift

case action
when "do"
  File.open("tmp_homemaker_generated.yml", "w") do |f|
    f.write(config.to_homemaker(:yaml))
  end

  profile = ARGV.shift
  found_profile = config.profiles.find { |p| p.name == profile }

  raise "Profile #{profile} unknown" unless found_profile

  system("homemaker -task #{found_profile.name} tmp_homemaker_generated.yml .")
  system("rm tmp_homemaker_generated.yml")

  system("rm -rf current/*")
  profile_dirs = []
  Dir.chdir('profiles') do
    profile_dirs = Dir.glob('*').select { |f| File.directory? f }
  end

  config.used_profiles_for(found_profile).each do |profile|
    if profile_dirs.include? profile.name
      system("ln -s #{profile.name} current/#{profile.name}")
    end
  end

when "list"
  puts config.leaf_profiles
else
  usage
end