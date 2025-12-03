import 'dart:io';
import 'package:yaml/yaml.dart';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found');
    exit(1);
  }

  try {
    // Read current pubspec.yaml
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content);
    
    // Extract current version
    final currentVersion = yaml['version'] as String;
    final parts = currentVersion.split('+');
    
    final versionPart = parts[0]; // e.g., "6.0.0"
    final buildNumber = int.parse(parts.length > 1 ? parts[1] : '0');
    final newBuildNumber = buildNumber + 1;
    final newVersion = '$versionPart+$newBuildNumber';
    
    // Replace version in pubspec.yaml
    final updatedContent = content.replaceFirst(
      'version: $currentVersion',
      'version: $newVersion',
    );
    
    pubspecFile.writeAsStringSync(updatedContent);
    
    print('✅ Build number incremented: $currentVersion → $newVersion');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
