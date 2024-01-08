import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: CollisionBenchmark()));
}

// USAGE: Switch between HasQuadTreeCollisionDetection and HasCollisionDetection
//        in the class definition below to see the difference.

class CollisionBenchmark extends FlameGame with HasQuadTreeCollisionDetection {
  static const robotCount = 800;

  static const int percentStatic = 99;

  late final String label =
      // ignore: unnecessary_type_check
      '${this is HasQuadTreeCollisionDetection ? 'QuadTree' : 'Standard'} '
      'with $robotCount entities, '
      '$percentStatic% static, '
      '${kDebugMode ? 'debug' : 'profile'} mode, '
      'normal';

  late final ScreenHitbox screenHitbox;

  @override
  Future<void> onLoad() async {
    // Add buffer to the broadphase collision detection.
    const offscreenOffset = 100.0;
    // ignore: unnecessary_type_check
    if (this is HasQuadTreeCollisionDetection) {
      // ignore: unnecessary_cast
      (this as HasQuadTreeCollisionDetection).initializeCollisionDetection(
        mapDimensions: Rect.fromLTRB(
          -offscreenOffset,
          -offscreenOffset,
          size.x + offscreenOffset,
          size.y + offscreenOffset,
        ),
      );
    }

    final paint = BasicPalette.gray.paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    screenHitbox = ScreenHitbox();
    await add(screenHitbox);

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
    const portionStatic = percentStatic / 100;
    final random = Random(42);
    for (var y = 20.0; y < size.y && index < robotCount; y += 30) {
      for (var x = 20.0; x < size.x && index < robotCount; x += 20) {
        // Every n-th robot is static, depending on portionStatic.
        final isStatic = random.nextDouble() < portionStatic;
        add(Robot(
          index,
          isStatic: isStatic,
        )..position.setValues(x, y));
        index++;
      }
    }
    assert(
        index == robotCount,
        'Screen too small to accommodate '
        '$robotCount robots (only ${index + 1} spawned)');

    add(FpsTextComponent(decimalPlaces: 2));
    add(
      TextComponent(
        text: label,
        position: Vector2(20, size.y - 40),
      ),
    );
  }
}

class Robot extends PositionComponent
    with CollisionCallbacks, HasGameRef<CollisionBenchmark> {
  static final Random _random = Random(42);

  final _paint = Paint()..color = const Color(0x99FFFFFF);

  late final RectangleHitbox _ownHitbox;

  final int id;

  final bool isStatic;

  final double _offset;

  Robot(this.id, {required this.isStatic})
      : _offset = Random(42 + id).nextDouble() * 2 * pi,
        super(size: Vector2(10, 20), anchor: Anchor.center);

  @override
  void onLoad() {
    _ownHitbox = RectangleHitbox()..isSolid = true;
    add(_ownHitbox);

    add(
      RectangleComponent(
        size: size,
        paint: _paint,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isStatic) {
      return;
    }

    const turningSpeed = 0.2;
    const movementSpeed = 50.0;

    angle = sin(_offset + gameRef.currentTime() * turningSpeed) * pi;

    final vector = Vector2(
      sin(angle),
      -cos(angle),
    )..scale(movementSpeed * dt);
    position.add(vector);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other == game.screenHitbox) {
      // Hit the border.
      position = Vector2.random(_random)..multiply(gameRef.size);
      _paint.color = const Color(0x99FFFF00);
    } else {
      _paint.color = const Color(0x99FF0000);
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    _paint.color = const Color(0x99FFFFFF);
  }
}
