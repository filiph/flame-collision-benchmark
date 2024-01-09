import 'dart:developer';
import 'dart:math';
import 'dart:typed_data';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(GameWidget(game: CollisionBenchmark()));
}

class CollisionBenchmark extends FlameGame with HasQuadTreeCollisionDetection {
  static const robotCount = 800;

  @override
  Future<void> onLoad() async {
    // Add buffer to the broadphase collision detection.
    const offscreenOffset = 100.0;
    initializeCollisionDetection(
        mapDimensions: Rect.fromLTRB(-offscreenOffset, -offscreenOffset,
            size.x + offscreenOffset, size.y + offscreenOffset));

    final paint = BasicPalette.gray.paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    add(ScreenHitbox());
    add(
      CircleComponent(
        position: Vector2(100, 100),
        radius: 50,
        paint: paint,
        children: [CircleHitbox()],
      ),
    );
    add(
      CircleComponent(
        position: Vector2(150, 500),
        radius: 50,
        paint: paint,
        children: [CircleHitbox()],
      ),
    );
    add(
      RectangleComponent(
        position: Vector2.all(300),
        size: Vector2.all(100),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );
    add(
      RectangleComponent(
        position: Vector2.all(500),
        size: Vector2(100, 200),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );
    add(
      RectangleComponent(
        position: Vector2(550, 200),
        size: Vector2(200, 150),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );

    var index = 0;
    for (var y = 20.0; y < size.y && index < robotCount; y += 50) {
      for (var x = 20.0; x < size.x && index < robotCount; x += 40) {
        add(Robot(index)..position.setValues(x, y));
        index++;
      }
    }
    assert(
        index == robotCount,
        'Screen too small to accommodate '
        '$robotCount robots (only ${index + 1} spawned)');

    add(FpsTextComponent(decimalPlaces: 2));
  }

  @override
  void update(double dt) {
    // Save previous frame measurements.
    if (measurementIndex >= 0 && measurementIndex < measurementCountMax) {
      measurements[measurementIndex] = measurementAggregator;
    }

    // Zero out measurement.
    measurementAggregator = 0;

    measurementIndex += 1;

    if (measurementIndex >= measurementCountMax) {
      // Exit app.
      for (final m in measurements) {
        print(m);
      }
      SystemNavigator.pop();
    }
    super.update(dt);
  }

  @override
  void updateTree(double dt) {
    // Fix update to a fixed step so that benchmark runs are comparable.
    super.updateTree(1 / 60);
  }
}

int measurementAggregator = 0;
int measurementIndex = 0;
const measurementCountMax = 10 * 60;
final Uint64List measurements = Uint64List(measurementCountMax);

class Robot extends PositionComponent
    with CollisionCallbacks, HasGameRef<CollisionBenchmark> {
  final _paint = Paint()..color = Color(0x99FFFFFF);

  late final RectangleHitbox _ownHitbox;

  late final List<ShapeHitbox> _ownHitboxIgnoreList = [_ownHitbox];

  final int id;

  Robot(this.id) : super(size: Vector2(10, 20), anchor: Anchor.center);

  @override
  void onLoad() {
    _ownHitbox = RectangleHitbox()..isSolid = true;
    add(_ownHitbox);

    add(RectangleComponent(
      size: size,
      paint: _paint,
    ));
  }

  /// For reusing.
  final _raycastResultLeft = RaycastResult<ShapeHitbox>();
  final _raycastResultCenter = RaycastResult<ShapeHitbox>();
  final _raycastResultRight = RaycastResult<ShapeHitbox>();

  bool raycastFilter(ShapeHitbox hitbox) {
    if (hitbox == _ownHitbox) return false;
    final parent = hitbox.parent!;
    if (parent is! Robot) return true;
    return (parent.id % 2) == 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    const raySpread = 30.0;
    const maxRayDistance = 300.0;

    Timeline.startSync("raycast");
    final roundStart = Timeline.now;

    // final ignoreHitboxes = game.children
    //     .where((component) {
    //       if (component == this) return true;
    //       if (component is Robot) {
    //         return id % 2 != 0;
    //       }
    //       return false;
    //     })
    //     .map((component) =>
    //         component.children.whereType<ShapeHitbox>().firstOrNull)
    //     .nonNulls
    //     .toList(growable: false);

    final centerRay =
        Ray2(origin: position, direction: Vector2(0, -1)..rotate(angle));
    gameRef.collisionDetection.raycast(
      centerRay,
      maxDistance: maxRayDistance,
      // ignoreHitboxes: ignoreHitboxes,
      // ignoreHitboxes: [_ownHitbox],
      ignoreHitboxes: _ownHitboxIgnoreList,
      // hitboxFilter: (b) => b != _ownHitbox,
      // hitboxFilter: raycastFilter,
      out: _raycastResultCenter,
    );
    final centerDistance = _raycastResultCenter.distance ?? double.infinity;

    final leftRay = Ray2(
        origin: position,
        direction: Vector2(0, -1)
          ..rotate(angle)
          ..rotate(radians(-raySpread)));
    gameRef.collisionDetection.raycast(
      leftRay,
      maxDistance: maxRayDistance,
      // ignoreHitboxes: ignoreHitboxes,
      // ignoreHitboxes: [_ownHitbox],
      ignoreHitboxes: _ownHitboxIgnoreList,
      // hitboxFilter: (b) => b != _ownHitbox,
      // hitboxFilter: raycastFilter,
      out: _raycastResultLeft,
    );
    final leftDistance = _raycastResultLeft.distance ?? double.infinity;

    final rightRay = Ray2(
        origin: position,
        direction: Vector2(0, -1)
          ..rotate(angle)
          ..rotate(radians(raySpread)));
    gameRef.collisionDetection.raycast(
      rightRay,
      maxDistance: maxRayDistance,
      // ignoreHitboxes: ignoreHitboxes,
      // ignoreHitboxes: [_ownHitbox],
      ignoreHitboxes: _ownHitboxIgnoreList,
      // hitboxFilter: (b) => b != _ownHitbox,
      // hitboxFilter: raycastFilter,
      out: _raycastResultRight,
    );
    final rightDistance = _raycastResultRight.distance ?? double.infinity;

    final roundEnd = Timeline.now;
    measurementAggregator += roundEnd - roundStart;
    Timeline.finishSync();

    const sharpTurningSpeed = 1.0;
    const slowTurningSpeed = 0.2;
    const movementSpeed = 50.0;

    const tooClose = 30.0;
    if (centerDistance < tooClose &&
        leftDistance < tooClose &&
        rightDistance < tooClose) {
      // Stop and turn.
      final sign = id % 2 == 0 ? 1 : -1;
      angle += sign * sharpTurningSpeed * dt;
    } else if (centerDistance < tooClose) {
      angle += sharpTurningSpeed * dt;
    } else if (leftDistance < tooClose) {
      angle += sharpTurningSpeed * dt;
    } else if (rightDistance < tooClose) {
      angle -= sharpTurningSpeed * dt;
    } else if (leftDistance != rightDistance) {
      final sign = leftDistance > rightDistance ? -1 : 1;
      angle += sign * slowTurningSpeed * dt;

      final vector = Vector2(
        sin(angle),
        -cos(angle),
      )..scale(movementSpeed * dt);
      position.add(vector);
    } else {
      // Just go straight.
      final vector = Vector2(
        sin(angle),
        -cos(angle),
      )..scale(movementSpeed * dt);
      position.add(vector);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final intersection in {
      _raycastResultLeft.intersectionPoint,
      _raycastResultRight.intersectionPoint,
      _raycastResultCenter.intersectionPoint,
    }) {
      if (intersection != null) {
        final localCenter = anchor.toVector2()..multiply(size);
        final localIntersection = toLocal(intersection);
        canvas.drawLine(localCenter.toOffset(), localIntersection.toOffset(),
            Paint()..color = Color(0xFF33FFFF));
      }
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    _paint.color = Color(0x99FF0000);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    _paint.color = Color(0x99FFFFFF);
  }
}
