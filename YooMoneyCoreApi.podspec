Pod::Spec.new do |spec|
  spec.name         = 'YooMoneyCoreApi'
  spec.version      = '1.11.0'
  spec.homepage     = 'https://github.com/yoomoney/yoomoney-core-api-swift'
  spec.license = {
    :type => "MIT",
    :file => "LICENSE"
  }
  spec.authors      = 'YooMoney'
  spec.summary      = 'YooMoney Core API library'
  spec.source       = {
    :git => 'https://github.com/yoomoney/yoomoney-core-api-swift.git',
    :tag => spec.version
  }
  spec.module_name  = 'YooMoneyCoreApi'

  spec.ios.deployment_target  = '8.0'
  spec.watchos.deployment_target = '2.0'

  spec.swift_version = '5.0'

  spec.source_files  = 'YooMoneyCoreApi/**/*.swift'

  spec.dependency 'FunctionalSwift', '~> 1.5.0'
end
