Gem::Specification.new do |s|
  s.name        = "pbxplorer"
  s.version     = "1.2.0"
  s.date        = "2017-07-11"
  s.summary     = "Xcode project file editor"
  s.description = "pbxplorer is a set of Ruby classes for parsing, editing, and saving Xcode project (.pbxproj) files. It can also be used to explore the contents of a project using the interactive Ruby shell."
  s.authors     = ["Mark Smith"]
  s.email       = "mark@camazotz.com"
  s.files       = Dir["{test,lib}/**/*"] + ["README.md", "Rakefile", "pbxplorer.gemspec"]
  s.homepage    = "http://github.com/mjmsmith/pbxplorer"
end
