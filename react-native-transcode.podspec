require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-transcode"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = "react-native-transcode - a video transcoder for react-native"
  s.homepage     = "https://github.com/github_account/react-native-transcode"
  s.license      = "MIT"
  s.authors      = { "Sam Elsamman" => "yourname@email.com" }
  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/github_account/react-native-transcode.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,swift}"
  s.requires_arc = true

  s.dependency "React"
  # ...
  # s.dependency "..."
end

