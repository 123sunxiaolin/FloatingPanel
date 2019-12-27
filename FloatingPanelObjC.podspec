Pod::Spec.new do |s|

  s.name                = "FloatingPanelObjC"
  s.version             = "1.3.2"
  s.summary             = "FloatingPanel is a clean and easy-to-use UI component of a floating panel interface."
  s.description         = <<-DESC
FloatingPanel is a clean and easy-to-use UI component for a new interface introduced in Apple Maps, Shortcuts and Stocks app.
The new interface displays the related contents and utilities in parallel as a user wants.
                   DESC
  s.homepage            = "https://github.com/SCENEE/FloatingPanel"
  # s.screenshots       = ""

  s.platform            = :ios, "8.0"
  s.source              = { :git => "https://github.com/SCENEE/FloatingPanel.git", :tag => "v#{s.version}" }
  s.source_files        = "Framework/Sources/*.swift", "Framework/Sources/ObjC/*.{h,m}"
  s.public_header_files = "Framework/Sources/ObjC/*.h"

  s.swift_version       = "4.0"
  s.pod_target_xcconfig = { 'SWIFT_WHOLE_MODULE_OPTIMIZATION' => 'YES', 'APPLICATION_EXTENSION_API_ONLY' => 'YES', 'DEFINES_MODULE' => 'YES', 'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'YES', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '__OBJC__' }

  s.framework           = "UIKit"

  s.author              = { "Shin Yamamoto" => "shin@scenee.com" }
  s.license             = { :type => "MIT", :file => "LICENSE" }
  s.social_media_url    = "https://twitter.com/scenee"
end
