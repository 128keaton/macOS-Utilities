platform :osx, '10.13'
inhibit_all_warnings!

target 'macOS Utilities' do
 use_frameworks!
 pod 'AppFolder', '~> 0.2.0'
 pod 'Alamofire'
 pod 'Alamofire-SwiftyJSON'
 pod 'CocoaLumberjack/Swift'
 pod 'CocoaAsyncSocket'
 pod "PaperTrailLumberjack/Swift", :git => "https://github.com/128keaton/PaperTrailLumberjack"
 pod 'BMExtendablePageController', :git => "https://github.com/Foboz/BMExtPageController"
 pod "STPrivilegedTask"
 pod 'XMLParsing', :git => 'https://github.com/128keaton/XMLParsing.git'
 pod 'MultiPeer', :git => 'https://github.com/128keaton/MultiPeer.git', :tag => '0.1.2'
 pod 'AudioKit'
 pod "XLFacility", "~> 1.0"
 pod 'Bugsnag'
 pod 'SwiftDisks', :git => 'https://github.com/128keaton/SwiftDisks.git'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    puts "#{target.name}"
  end
end
