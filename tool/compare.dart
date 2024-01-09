import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln("Must include path to two files.");
    exit(2);
  }

  var original = MeasurementsFile(arguments[0]);
  var originalMeasurements = original.read();
  var improved = MeasurementsFile(arguments[1]);
  var improvedMeasurements = improved.read();

  var diffs = computeDiffs(originalMeasurements, improvedMeasurements, 0);

  stdout.writeln(
      '<-- (improvement)                  UI thread                (deterioration) -->\n\n');
  stdout.writeln(createAsciiVisualization(diffs));

  int sum(int a, int b) => a + b;

  var report = createReport(
    diffs,
    originalMeasurements.length,
    improvedMeasurements.length,
    originalMeasurements.fold(0, sum),
    improvedMeasurements.fold(0, sum),
  );
  stdout.writeln(report);
}

class MeasurementsFile {
  final String path;

  MeasurementsFile(this.path);

  List<int> read() {
    var file = File(path);
    var contents = file.readAsStringSync();
    var lines = LineSplitter().convert(contents);
    var result = <int>[];
    for (var line in lines) {
      if (!line.startsWith("flutter: ")) continue;
      var candidate = line.substring("flutter:".length).trim();
      var integer = int.tryParse(candidate);
      if (integer != null) {
        result.add(integer);
      }
    }
    return result;
  }
}

List<int> computeDiffs(List<int> original, List<int> improved, int threshold) {
  final originalOrdered =
      List<int>.from(original.where((m) => m > threshold), growable: false)
        ..sort();
  final improvedOrdered =
      List<int>.from(improved.where((m) => m > threshold), growable: false)
        ..sort();
  final length = min(originalOrdered.length, improvedOrdered.length);

  return List<int>.generate(length, (index) {
    // Take two measurements that are at the same position
    // in the sorted lists.
    final measurementOriginal =
        originalOrdered[(index / length * originalOrdered.length).round()];
    final measurementImproved =
        improvedOrdered[(index / length * improvedOrdered.length).round()];
    return measurementImproved - measurementOriginal;
  });
}

/// Histogram always shows this range: ±8.0ms.
///
/// That's a huge number, since an improvement by that much can easily
/// erase all jank.
const _histogramRange = 8000;

String createAsciiVisualization(List<int> measurements) {
  final buf = StringBuffer();

  final histogram = Histogram(measurements, forceRange: _histogramRange);

  // We want a bucket for the exact middle of the range.
  assert(Histogram.bucketCount.isOdd);
  // Number of characters on each side of the center line.
  const sideSize = (Histogram.bucketCount - 1) ~/ 2;

  // How many characters should the largest bucket be high?
  const height = 20;

  for (var row = 1; row <= height; row++) {
    for (var column = 0; column < Histogram.bucketCount; column++) {
      final value = histogram.bucketsNormalized[column];
      if (value > (height - row + 0.5) / height) {
        // Definitely above the line.
        buf.write('█');
      } else if (value > (height - row + 0.05) / height) {
        // Meaningfully above the line.
        buf.write('▄');
      } else if (value > (height - row) / height && row == height) {
        // A tiny bit above the line, and also at the very bottom
        // of the graph (just above the axis). We show a dot here so that
        // this information isn't completely lost, even if it was just
        // one measurement.
        buf.write('.');
      } else {
        buf.write(' ');
      }
    }
    buf.writeln();
  }

  buf.writeln('─' * Histogram.bucketCount);

  final boundValueString =
      '${(histogram.lowestBound / 1000).abs().toStringAsFixed(1)}ms';

  buf.writeln('-${boundValueString.padRight(sideSize - 1)}'
      '^'
      '${boundValueString.padLeft(sideSize)}');

  return buf.toString();
}

/// A histogram around 0.
class Histogram {
  static const bucketCount = 79;
  static const sideSize = (bucketCount - 1) ~/ 2;
  final bucketMemberCounts = List<int>.filled(bucketCount, 0);
  late final List<double> bucketsNormalized;
  late final double lowestBound;

  // The width is 79 characters (so that there's a center line,
  // and so that it covers a standard 80-wide terminal).
  late final double highestBound;
  // Number of characters on each side of the center line.
  late final double bucketWidth;

  /// Creates a histogram from a list of [measurements].
  ///
  /// If [forceRange] is specified, the histogram will only span from `-x`
  /// to `+x`, exactly. The measurements that fall outside this range will be
  /// added to the outermost buckets.
  Histogram(List<int> measurements, {int? forceRange}) {
    // Maximum distance from 0.
    var distance = forceRange ??
        measurements.fold<int>(
            0, (previousValue, element) => max(previousValue, element.abs()));

    lowestBound = (-distance - 1);
    highestBound = (distance + 1);

    bucketWidth = (highestBound - lowestBound) / bucketCount;

    for (final m in measurements) {
      var bucketIndex = ((m - lowestBound) / bucketWidth).floor();
      if (bucketIndex < 0) {
        assert(forceRange != null);
        bucketIndex = 0;
      }
      if (bucketIndex >= bucketCount) {
        assert(forceRange != null);
        bucketIndex = bucketCount - 1;
      }
      bucketMemberCounts[bucketIndex] += 1;
    }

    final highestCount = bucketMemberCounts.fold<int>(0, max);
    bucketsNormalized = List<double>.generate(
        bucketCount, (index) => bucketMemberCounts[index] / highestCount);
  }
}

String createReport(
  List<int> measurements,
  int originalCount,
  int improvedCount,
  int originalRuntime,
  int improvedRuntime,
) {
  final buf = StringBuffer();

  buf.writeln("* $originalCount vs $improvedCount measurements");

  final runtimeDifference = improvedRuntime - originalRuntime;
  final gerund = runtimeDifference <= 0 ? 'improvement' : 'worsening';
  buf.writeln('* '
      '${(runtimeDifference.abs() / originalRuntime * 100).toStringAsFixed(1)}% '
      '(${(runtimeDifference / 1000).toStringAsFixed(0)}ms) '
      '$gerund of total execution time');

  // 833 microseconds is 5% of a 60fps frame budget
  // 1000 microseconds is 6% of a 60fps frame budget
  const threshold = 1000;
  final betterMeasurementsWithPadding =
      measurements.where((m) => m < -threshold).length;
  final betterPercentWithPadding =
      (betterMeasurementsWithPadding / measurements.length) * 100;
  buf.writeln('* ${betterPercentWithPadding.toStringAsFixed(1)}% '
      'of individual measurements improved by 1ms+');

  final worseMeasurementsWithPadding =
      measurements.where((m) => m > threshold).length;
  final worsePercentWithPadding =
      (worseMeasurementsWithPadding / measurements.length) * 100;
  buf.writeln('* ${worsePercentWithPadding.toStringAsFixed(1)}% '
      'of individual measurements worsened by 1ms+');

  return buf.toString();
}
