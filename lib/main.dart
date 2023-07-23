import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: CollisionBenchmark()));
}

class CollisionBenchmark extends FlameGame with HasQuadTreeCollisionDetection {
  static const robotCount = 200;

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
}

class Robot extends PositionComponent
    with CollisionCallbacks, HasGameRef<CollisionBenchmark> {
  final _paint = Paint()..color = Color(0x99FFFFFF);

  late final RectangleHitbox _ownHitbox;

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

  @override
  void update(double dt) {
    super.update(dt);

    const raySpread = 30.0;
    const maxRayDistance = 100.0;

    final centerRay =
        Ray2(origin: position, direction: Vector2(0, -1)..rotate(angle));
    gameRef.collisionDetection.raycast(
      centerRay,
      maxDistance: maxRayDistance,
      ignoreHitboxes: [_ownHitbox],
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
      ignoreHitboxes: [_ownHitbox],
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
      ignoreHitboxes: [_ownHitbox],
      out: _raycastResultRight,
    );
    final rightDistance = _raycastResultRight.distance ?? double.infinity;

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
