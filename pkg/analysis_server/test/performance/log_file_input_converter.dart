// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library input.transformer.log_file;

import 'dart:convert';

import 'package:analyzer/src/generated/java_engine.dart';
import 'package:logging/logging.dart';

import 'input_converter.dart';
import 'operation.dart';

const CONNECTED_MSG_FRAGMENT = ' <= {"event":"server.connected"';
final int NINE = '9'.codeUnitAt(0);
const RECEIVED_FRAGMENT = ' <= {';
const SENT_FRAGMENT = ' => {';
final int ZERO = '0'.codeUnitAt(0);

/**
 * [LogFileInputConverter] converts a log file stream
 * into a series of operations to be sent to the analysis server.
 */
class LogFileInputConverter extends CommonInputConverter {
  LogFileInputConverter(Map<String, String> srcPathMap) : super(srcPathMap);

  @override
  Operation convert(String line) {
    try {
      String timeStampString = _parseTimeStamp(line);
      String data = line.substring(timeStampString.length);
      if (data.startsWith(RECEIVED_FRAGMENT)) {
        Map<String, dynamic> json = JSON.decode(data.substring(4));
        if (json.containsKey('event')) {
          return convertNotification(json);
        }
        return null;
      } else if (data.startsWith(SENT_FRAGMENT)) {
        Map<String, dynamic> json = JSON.decode(data.substring(4));
        if (json.containsKey('method')) {
          return convertRequest(json);
        }
        return null;
      }
      logger.log(Level.INFO, 'unknown input line: $line');
      return null;
    } catch (e, s) {
      throw new AnalysisException(
          'Failed to parse line\n  $line', new CaughtException(e, s));
    }
  }

  /**
   * Determine if the given line is from an instrumentation file.
   * For example:
   * `1428347977499 <= {"event":"server.connected","params":{"version":"1.6.0"}}`
   */
  static bool isFormat(String line) {
    String timeStampString = _parseTimeStamp(line);
    int start = timeStampString.length;
    int end = start + CONNECTED_MSG_FRAGMENT.length;
    return (10 < start && end < line.length) &&
        line.substring(start, end) == CONNECTED_MSG_FRAGMENT;
  }

  /**
   * Parse the given line and return the millisecond timestamp or `null`
   * if it cannot be determined.
   */
  static String _parseTimeStamp(String line) {
    int index = 0;
    while (index < line.length) {
      int code = line.codeUnitAt(index);
      if (code < ZERO || NINE < code) {
        return line.substring(0, index);
      }
      ++index;
    }
    return line;
  }
}
