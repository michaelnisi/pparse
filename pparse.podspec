Pod::Spec.new do |s|
  s.name         = 'pparse'
  s.version      = '0.1.0'
  s.summary      = 'parse podcasts'
  s.license      = 'MIT'
  s.author       = { 'Michael Nisi' => 'michael.nisi@gmail.com' }

  s.platform     = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.requires_arc = true

  s.source_files = 'pparse', 'pparse/**/*.{h,m}'
  s.public_header_files = 'pparse/pparse.h'
  s.library = 'xml2'
  s.requires_arc = true

  s.dependency 'yajl'
end
