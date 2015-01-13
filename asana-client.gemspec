Gem::Specification.new do |s|
    s.name = 'asana-client'
    s.version = '1.0.0'
    s.date = '2013-02-26'
    s.summary = "Ruby client for Asana's REST API"
    s.description = "Command-line client and library for browsing, creating, and completing Asana tasks."
    s.authors = ["Tommy MacWilliam"]
    s.email = "tmacwilliam@cs.harvard.edu"
    s.files         = `git ls-files -z`.split("\x0")
    s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
    # s.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    s.require_paths = ["lib"]
    s.add_dependency "chronic", ">= 0.6.7"
    s.add_dependency "json", ">= 1.6.6"
    s.homepage = "https://github.com/tmacwill/asana-client"
end
