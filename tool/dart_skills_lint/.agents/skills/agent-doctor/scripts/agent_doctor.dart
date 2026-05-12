#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Bootstraps and diagnoses the workspace agent skills configuration.
///
/// Locates [skills-lock.json] files, checks if skills are present on disk,
/// and installs them using [npx skill experimental_install].
void main(List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Prints the bootstrap commands without running them or installing skills.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Prints usage details.');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on ArgParserException catch (e) {
    print('Argument error: ${e.message}');
    printUsage(parser);
    exit(1);
  }

  if (argResults['help'] == true) {
    printUsage(parser);
    exit(0);
  }

  final bool dryRun = argResults['dry-run'] == true;
  print('Starting Agent Doctor setup analysis...');

  final Directory rootDir = Directory.current;
  final List<File> lockFiles = findLockFiles(rootDir);

  if (lockFiles.isEmpty) {
    print('No skills-lock.json files found in the workspace.');
    exit(0);
  }

  bool needsInstall = false;

  for (final File lockFile in lockFiles) {
    final List<String> missing = checkMissingSkills(lockFile);
    if (missing.isNotEmpty) {
      print('Found missing skills for lockfile at ${lockFile.path}:');
      for (final String skill in missing) {
        print('  - $skill');
      }
      needsInstall = true;
    }
  }

  if (needsInstall) {
    if (dryRun) {
      print('\n[Dry-run] Missing skills detected.');
      for (final File lockFile in lockFiles) {
        print(
          '[Dry-run] Would run: npx skill experimental_install in directory: ${lockFile.parent.path}',
        );
      }
      exit(1);
    } else {
      print('\nMissing skills detected. Bootstrapping environment by running npx install...');
      bool success = true;
      for (final File lockFile in lockFiles) {
        final Directory lockFileDir = lockFile.parent;
        final bool installSuccess = await runNpxInstall(lockFileDir);
        if (!installSuccess) {
          success = false;
        }
      }
      exit(success ? 0 : 1);
    }
  } else {
    print('\nAll locked skills are already present on disk. Workspace is healthy.');
    exit(0);
  }
}

/// Prints argument usage information to the console.
void printUsage(ArgParser parser) {
  print('Usage: dart run agent_doctor.dart [options]');
  print(parser.usage);
}

/// Searches the [dir] recursively for [skills-lock.json] files.
///
/// Avoids traversing [.dart_tool] and [build/] directories.
/// Throws [FileSystemException] if directory listing fails.
List<File> findLockFiles(Directory dir) {
  final List<File> lockFiles = <File>[];
  try {
    for (final FileSystemEntity entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == 'skills-lock.json') {
        if (!entity.path.contains('.dart_tool') && !entity.path.contains('build/')) {
          lockFiles.add(entity);
        }
      }
    }
  } on FileSystemException catch (e) {
    print('FileSystemException during lockfile search: ${e.message}');
  }
  return lockFiles;
}

/// Reads a [lockFile] and identifies any skills not present on disk.
///
/// Checks under the lock-file directory [.agents/skills/<skill_name>] path.
/// Throws [FileSystemException] if reading the file fails, or
/// [FormatException] if the JSON parsing fails.
List<String> checkMissingSkills(File lockFile) {
  final List<String> missing = <String>[];
  try {
    final String content = lockFile.readAsStringSync();
    final Object? json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      print('Format error: lockfile root is not a JSON map.');
      return missing;
    }
    final Map<String, dynamic>? skills = json['skills'] as Map<String, dynamic>?;

    if (skills == null) {
      return missing;
    }

    final String lockDir = lockFile.parent.path;
    for (final String skillName in skills.keys) {
      final Directory skillFolder = Directory(p.join(lockDir, '.agents', 'skills', skillName));
      if (!skillFolder.existsSync()) {
        missing.add(skillName);
      }
    }
  } on FileSystemException catch (e) {
    print('FileSystemException reading lockfile ${lockFile.path}: ${e.message}');
  } on FormatException catch (e) {
    print('FormatException (invalid JSON) inside lockfile ${lockFile.path}: ${e.message}');
  }
  return missing;
}

/// Launches the npx skill installation recovery process in the [workingDir].
///
/// Pipes processes outputs to [stdout] and [stderr] to make sure all error details
/// are visible to the user. Returns true if command finishes successfully.
Future<bool> runNpxInstall(Directory workingDir) async {
  print('Executing: npx skill experimental_install inside ${workingDir.path}');
  try {
    final Process process = await Process.start(
      'npx',
      ['skill', 'experimental_install'],
      workingDirectory: workingDir.path,
      runInShell: true,
    );

    process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);

    final int exitCode = await process.exitCode;
    if (exitCode == 0) {
      print('Skills installed successfully!');
      return true;
    } else {
      print('npx skill experimental_install failed with exit code $exitCode.');
      return false;
    }
  } on ProcessException catch (e) {
    print('ProcessException executing npx installer command: ${e.message}');
    return false;
  }
}
