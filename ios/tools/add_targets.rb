#!/usr/bin/env ruby
# Inietta nel progetto Runner.xcodeproj i target nativi aggiuntivi
# (widget WidgetKit e, in seguito, l'app Apple Watch) senza bisogno di Xcode.
# Eseguito in CI dopo `flutter build ios`.
require 'xcodeproj'

PROJECT = 'Runner.xcodeproj'
TEAM = ENV['APPLE_TEAM_ID'] || ''

# Versioni dall'app Flutter (devono combaciare con quelle del target Runner)
name = '1.0.0'
number = '1'
if File.exist?('Flutter/Generated.xcconfig')
  File.readlines('Flutter/Generated.xcconfig').each do |l|
    name = $1.strip if l =~ /^FLUTTER_BUILD_NAME=(.+)$/
    number = $1.strip if l =~ /^FLUTTER_BUILD_NUMBER=(.+)$/
  end
end
puts "[add_targets] versione #{name} (#{number}), team #{TEAM}"

project = Xcodeproj::Project.open(PROJECT)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('Target Runner non trovato') unless runner

def ensure_widget(project, runner, name_ver, number_ver, team)
  tname = 'PGSWidget'
  if project.targets.any? { |t| t.name == tname }
    puts "[add_targets] #{tname} già presente, salto"
    return
  end
  puts "[add_targets] creo target #{tname}"
  ext = project.new_target(:app_extension, tname, :ios, '16.0')

  # sorgenti
  group = project.main_group.find_subpath(tname, true)
  group.set_source_tree('SOURCE_ROOT')
  swift = group.new_reference("#{tname}/#{tname}.swift")
  ext.add_file_references([swift])

  ext.build_configurations.each do |c|
    s = c.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = 'it.pgssalgen.pgs.PGSWidget'
    s['INFOPLIST_FILE'] = "#{tname}/Info.plist"
    s['SWIFT_VERSION'] = '5.0'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['MARKETING_VERSION'] = name_ver
    s['CURRENT_PROJECT_VERSION'] = number_ver
    s['DEVELOPMENT_TEAM'] = team
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['SKIP_INSTALL'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    s['ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS'] = 'NO'
  end

  # dipendenza + embed nell'app
  runner.add_dependency(ext)
  phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
  phase ||= runner.new_copy_files_build_phase('Embed App Extensions')
  phase.symbol_dst_subfolder_spec = :plug_ins
  bf = phase.add_file_reference(ext.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

ensure_widget(project, runner, name, number, TEAM)

project.save
puts "[add_targets] fatto. Target: #{project.targets.map(&:name).join(', ')}"
