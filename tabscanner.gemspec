# frozen_string_literal: true

require_relative "lib/tabscanner/version"

Gem::Specification.new do |spec|
  spec.name = "tabscanner"
  spec.version = Tabscanner::VERSION
  spec.authors = ["Forrest Chang"]
  spec.email = ["fchang@hedgeye.com"]

  spec.summary = "Ruby gem for processing receipt images using the Tabscanner API"
  spec.description = "A Ruby gem that provides a simple interface for submitting receipt images to the Tabscanner API and retrieving parsed receipt data. Features include automatic polling, comprehensive error handling, debug mode, and environment-based configuration."
  spec.homepage = "https://github.com/fkchang/tabscanner"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fkchang/tabscanner"
  spec.metadata["changelog_uri"] = "https://github.com/fkchang/tabscanner/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies for HTTP client functionality
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"

  # Development dependencies for testing
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
