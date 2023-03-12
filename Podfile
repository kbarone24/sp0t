platform :ios, '15.0'

# ignore all warnings from all pods
inhibit_all_warnings!

target 'Spot' do
project 'Spot.xcodeproj'

use_frameworks!
  pod 'Firebase/Database'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'FirebaseAnalytics'
  pod 'Firebase/Core'
  pod 'FirebaseUI'
  pod 'RSKImageCropper'
  pod 'IQKeyboardManagerSwift'
  pod 'Firebase/Messaging'
  pod 'Firebase/Performance'
  pod 'Mixpanel-swift'
  pod 'FirebaseFirestoreSwift'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseUI/Storage'
  pod 'JPSVolumeButtonHandler'
  pod 'Firebase/Functions'
  pod 'SnapKit'
  pod 'R.swift'
  pod 'SwiftLint'
  pod 'GeoFire/Utils'
  pod 'NextLevel' # https://github.com/NextLevel/NextLevel
  pod 'PINCache'
  pod 'RealmSwift'
  pod 'iProgressHUD'

  target 'SpotTests' do
    inherit! :search_paths
    # Pods for testing
  end

  post_install do |installer|
  	installer.pods_project.build_configurations.each do |config|
    	config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  	end
    end	

end
