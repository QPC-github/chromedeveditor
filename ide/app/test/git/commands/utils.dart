// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.utils;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' show Random;

import '../../../lib/utils.dart';

final String sampleRepoUrl = 'https://github.com/devoncarew/spark_git_test.dart.git';

class GitLocation {
  String _name;
  html.DirectoryEntry entry;

  GitLocation() {
    Random r = new Random();
    _name = 'git_${r.nextInt(100)}';
  }

  String get name => _name;

  Future init() => getLocalDataDir(name).then((e) => entry = e);

  Future dispose() => entry.remove();
}
