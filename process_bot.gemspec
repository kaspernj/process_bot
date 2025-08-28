# frozen_string_literal: true

require_relative "lib/process_bot/version"

Gem::Specification.new do |spec|
  spec.name = "process_bot"
  spec.version = ProcessBot::VERSION
  spec.authors = ["kaspernj"]
  spec.email = ["k@spernj.org"]

  spec.summary = "Run and control processes."
  spec.description = "Run and control processes."
  spec.homepage = "https://github.com/kaspernj/process_bot"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kaspernj/process_bot"
  spec.metadata["changelog_uri"] = "https://github.com/kaspernj/process_bot/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:(?:bin|pkg|test|spec|features)/|\.(?:git|github|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "knjrbfw", ">= 0.0.116"
  spec.add_runtime_dependency "pry"
  spec.add_runtime_dependency "rake"
  spec.add_runtime_dependency "rspec"
  spec.add_runtime_dependency "string-cases"

  spec.metadata["rubygems_mfa_required"] = "true"
end
