#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sharedcore_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sharedcore_flutter'
  s.version          = '0.3.2'
  s.summary          = 'Binary Flutter bindings for SharedCore Rust.'
  s.description      = <<-DESC
Binary Flutter bindings for SharedCore Rust.
                       DESC
  s.homepage         = 'https://github.com/drainlin/sharedcore_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SharedCore' => 'sharedcore@example.invalid' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{c,h,swift}'
  s.public_header_files = 'Classes/**/*.h'
  s.vendored_frameworks = 'sharedcore_flutter/Frameworks/SharedCoreRustBinary.xcframework'
  s.resource_bundles = {
    'sharedcore_flutter_privacy' => [
      'sharedcore_flutter/Sources/sharedcore_flutter/PrivacyInfo.xcprivacy'
    ]
  }
  s.static_framework = true
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'DEAD_CODE_STRIPPING' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  s.user_target_xcconfig = {
    'DEAD_CODE_STRIPPING' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -Wl,-u,_sharedcore_flutter_retain_symbols',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -Wl,-u,_sharedcore_flutter_retain_symbols'
  }
  s.swift_version = '5.0'
end
