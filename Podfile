platform :ios, '16.0'

target 'Meetingsmanaged' do
  use_frameworks!

  # Archive handling - latest stable
  pod 'SSZipArchive', '~> 2.5'

  # Networking - latest Alamofire 5.x with async/await support
  pod 'Alamofire', '~> 5.9'

  # Image caching - latest SDWebImage with async/await
  pod 'SDWebImage', '~> 5.19'

  # Data persistence - latest Realm with type-safe queries
  pod 'RealmSwift', '~> 10.54'
end

target 'MedianIOSTests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
    end
  end
end