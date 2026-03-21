platform :ios, '13.0'

target 'Meetingsmanaged' do
  # Archive handling
  pod 'SSZipArchive', '~> 2.4'

  # Networking
  pod 'Alamofire', '~> 5.7'

  # JSON parsing
  pod 'SwiftyJSON', '~> 5.0'

  # Image caching
  pod 'SDWebImage', '~> 5.15'

  # Data persistence
  pod 'Realm', '~> 10.40'

  # Logging
  pod 'CocoaLumberjack/Swift', '~> 3.7'
end

target 'MedianIOSTests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end