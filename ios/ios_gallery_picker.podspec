Pod::Spec.new do |s|
  s.name             = 'ios_gallery_picker'
  s.version          = '0.0.1'
  s.summary          = 'Choose images from the library and capture new photos with ease.'
  s.description      = <<-DESC
  Choose images from the library and capture new photos with ease.
                         DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'ZLPhotoBrowser', '4.5.5'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
