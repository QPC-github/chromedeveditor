// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.file_operations;

import 'dart:async';
import 'dart:core';
import 'dart:js';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;

/**
 * Utility class to access HTML5 filesystem operations.
 *
 * TODO(grv): Add unittests.
 */
abstract class FileOps {

  /**
   * Creates directories recursively in a given [path]. The immediate parent
   * of the path may or may nor exist.
   */
  static Future<chrome.DirectoryEntry> createDirectoryRecursive(
      chrome.DirectoryEntry dir, String path) {

    if (path[path.length - 1] == '/') {
      path = path.substring(0, path.length -1);
    }

    List<String> pathParts = path.split("/");
    int i = 0;

    createDirectories(chrome.DirectoryEntry dir) {
      return dir.createDirectory(pathParts[i]).then(
          (chrome.DirectoryEntry dir) {
        i++;
        if (i == pathParts.length) return dir;

        return createDirectories(dir);
      });
    }
    return createDirectories(dir);
  }

  /**
   * Creates a file with a given [content] and [type]. Creates parent
   * directories if the immediate parent is absent.
   */
  static Future<chrome.FileEntry> createFileWithContent(
      chrome.DirectoryEntry root, String path, content, String type) {
    if (path[0] == '/') path = path.substring(1);
    List<String> pathParts = path.split('/');
    if (pathParts.length != 1) {
      return createDirectoryRecursive(root, path.substring(0,
          path.lastIndexOf('/'))).then((dir) {
        return _createFile(dir, pathParts[pathParts.length - 1], content, type);
      });
    } else {
      return _createFile(root, path, content, type);
    }
  }

  static Future<dynamic> readFileText(chrome.DirectoryEntry root, String path) {
    return root.getFile(path).then((chrome.ChromeFileEntry entry) {
      return entry.readText();
    });
  }

  static Future<dynamic> readFileBytes(chrome.DirectoryEntry root, String path) {
    return root.getFile(path).then((chrome.ChromeFileEntry entry) {
      return entry.readBytes();
    });
  }

  /**
   * Lists the files in a given [root] directory.
   */
  static Future<List<chrome.Entry>> listFiles(chrome.DirectoryEntry root) {
    return root.createReader().readEntries();
  }

  /**
   * Reads a given [blob] as a given [type]. The returned value will either be a
   * [String] or a [Uint8List].
   */
  static Future<dynamic> readBlob(chrome.Blob blob, String type) {
    Completer completer = new Completer();
    var reader = new JsObject(context['FileReader']);
    reader['onload'] = (var event) {
      var result = reader['result'];

      if (result is JsObject) {
        var arrBuf = new chrome.ArrayBuffer.fromProxy(result);
        result = new Uint8List.fromList(arrBuf.getBytes());
      } else if (result is ByteBuffer) {
        result = new Uint8List.view(result);
      }

      completer.complete(result);
    };

    reader['onerror'] = (var domError) {
      completer.completeError(domError);
    };

    reader.callMethod('readAs' + type, [blob]);
    return completer.future;
  }

  /**
   * Copy contents of a [src] directory into a [dst] directory recursively.
   */
  static Future<chrome.DirectoryEntry> copyDirectory(chrome.DirectoryEntry src,
      chrome.DirectoryEntry dst) {
    return listFiles(src).then((List<chrome.Entry> entries) {
      return Future.forEach(entries, (chrome.Entry entry) {
        if (entry.isFile) {
          return (entry as chrome.ChromeFileEntry).readBytes().then((content) {
            return createFileWithContent(dst, entry.name, content, 'blob');
          });
        } else {
          return dst.createDirectory(entry.name).then(
              (chrome.DirectoryEntry dir) {
            return copyDirectory(entry, dir);
          });
        }
      }).then((_) => dst);
    });
  }

  static Future<chrome.FileEntry> _createFile(chrome.DirectoryEntry dir,
      String fileName, content, String type) {
    return dir.createFile(fileName).then((chrome.ChromeFileEntry entry) {
      if (type == 'Text') {
        return entry.writeText(content).then((_) => entry);
      } else if (type == 'blob') {
        content = new chrome.ArrayBuffer.fromBytes(content as List);
        return entry.writeBytes(content).then((_) => entry);
      } else {
        throw new UnsupportedError(
            "Writing of content type:${type} is not supported.");
      }
    });
  }
}
