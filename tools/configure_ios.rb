require 'xcodeproj'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
['development', 'production'].each do |flavor|
  ['Debug', 'Profile', 'Release'].each do |mode|
    name = "#{mode}-#{flavor}"
    ([project] + project.targets).each do |owner|
      original = owner.build_configurations.find { |c| c.name == mode }
      next unless original
      config = owner.build_configurations.find { |c| c.name == name }
      unless config
        config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
        config.name = name
        config.build_settings = Marshal.load(Marshal.dump(original.build_settings))
        config.base_configuration_reference = original.base_configuration_reference
        owner.build_configuration_list.build_configurations << config
      end
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      if owner.equal?(runner)
        config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "org.fieldkit.fieldkit#{flavor == 'development' ? '.dev' : ''}"
        config.build_settings['APP_DISPLAY_NAME'] = flavor == 'development' ? 'Dooms Day App Dev' : 'Dooms Day App'
        config.build_settings['FLUTTER_TARGET'] = flavor == 'development' ? 'lib/main_development.dart' : 'lib/main.dart'
      end
    end
  end
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(runner)
  scheme.set_launch_target(runner)
  scheme.launch_action.build_configuration = "Debug-#{flavor}"
  scheme.test_action.build_configuration = "Debug-#{flavor}"
  scheme.profile_action.build_configuration = "Profile-#{flavor}"
  scheme.analyze_action.build_configuration = "Debug-#{flavor}"
  scheme.archive_action.build_configuration = "Release-#{flavor}"
  scheme.save_as(project.path, flavor, true)
end
runner.build_configurations.each do |c|
  c.build_settings['APP_DISPLAY_NAME'] ||= 'Dooms Day App'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  c.build_settings['ARCHS[sdk=iphonesimulator*]'] = 'arm64'
end
group = project.main_group.find_subpath('Runner', true)
file = group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' } || group.new_file('PrivacyInfo.xcprivacy')
runner.resources_build_phase.add_file_reference(file) unless runner.resources_build_phase.files_references.include?(file)
project.save
