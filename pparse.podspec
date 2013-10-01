Pod::Spec.new do |s|
  s.name = 'pparse'
  s.version = '0.0.2'
  s.summary = 'parse feeds'
  s.homepage = 'https://github.com/michaelnisi/pparse'
  s.license = 'MIT'
  s.author = { 'Michael Nisi' => 'michael.nisi@gmail.com' }
  s.source = { :git => 'https://github.com/michaelnisi/pparse.git', :tag => '0.0.2' }
  s.platform = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.requires_arc = true
  s.source_files =  'pparse/**/*.{h,m}'
  s.public_header_files = 'pparse/pparse.h'
  s.requires_arc = true
  
  s.library = 'xml2'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
end
