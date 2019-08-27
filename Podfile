platform :osx, '10.12'
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
 pod 'RainbowSwift', :git => 'https://github.com/128keaton/Rainbow.git', :tag => '3.1.5-swift5'
 pod 'XMLParsing', :git => 'https://github.com/128keaton/XMLParsing.git'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    puts "#{target.name}"
  end
end
