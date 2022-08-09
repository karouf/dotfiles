#!/usr/bin/env ruby

require "yaml"

def find_profile_deps(config, profile)
  deps_names = config["profiles"][profile]["deps"]

  return [] unless deps_names
  deps = deps_names.map { |name| config["profiles"][name] }

  deps += deps_names.map do |dep_name|
    find_profile_deps(config, dep_name)
  end.flatten
    
  deps.uniq
end

config = YAML.load(File.read("profiles.yml"))

tasks = {}

target_profile = ARGV.shift

selected_profiles = find_profile_deps(config, target_profile)

selected_profiles.each do |profile|
end

packages = selected_profiles.map do |profile|
  case profile["packages"].class.to_s
  when "Array"
    profile["packages"]
  when "Hash"
    profile["packages"].keys
  else
    []
  end
end.flatten.uniq

tasks["packages"] = { "cmds" => [["sudo", "apt", "install", "-yqq"] + packages] }

tasks["default"] = { "deps" => ["packages"] }

output = { "tasks" => tasks }
#puts YAML.dump(output)

module Homestage
  class Config
    OUTPUT_FORMATS = %i[json toml yaml]

    attr_accessor :variables, :profiles

    def self.parse(file_path)
      config_file = YAML.load(File.read(file_path))

      raise InvalidConfig unless valid_config?(config_file)

      config = Config.new
      config.variables = config_file["variables"].map { |c| Variable.parse(c) } if config_file["variables"]
      config.profiles = config_file["profiles"].map { |c| Profile.parse(c) } if config_file["profiles"]
      config
    end

    #def initialize
    #  @variables = []
    #  @profiles = []
    #end
    
    def to_homemaker(format)
      raise UnsupportedFormat unless OUTPUT_FORMATS.include? format
    end

    private

    def self.valid_config?(file)
      file["profiles"] ? true : false
    end
    
    class InvalidConfig < RuntimeError; end
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

  class Profile
    attr_reader :name
    attr_accessor :deps, :packages

    def self.parse(config)
      profile = Profile.new(name: config.first)

      config = config.last

      profile.deps = config["deps"].map { |c| Dependency.parse(c) } if config["deps"]
      profile.packages = config["packages"].map { |c| Package.parse(c) } if config["packages"]
      profile.roles = config["roles"].map { |c| Role.parse(c) } if config["roles"]
    end

    def initialize(name:)
      @name = name
    end
  end

  class Package
    def self.parse(config)
    end
  end

  class Dependency
    def self.parse(config)
    end
  end

  class Role
    def self.parse(config)
    end
  end
end

config = Homestage::Config.parse("profiles.yml")
File.open("test_homemaker_generated.yml") do |f|
  f.write(config.to_homemaker(:yaml))
end
