import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Train colour palette
// ─────────────────────────────────────────────────────────────────────────────

enum TrainColor { blue, pink, red, green, yellow, white }

// ─────────────────────────────────────────────────────────────────────────────
// Network node  (tunnel | fork | station)
// ─────────────────────────────────────────────────────────────────────────────

enum NodeType { tunnel, fork, station }

/// A point in the track network.
///
/// • [tunnel]  – the one spawn point on the left edge.
/// • [fork]    – Y-junction with 2 exits; [activeExit] chooses which branch.
/// • [station] – terminal; [stationColor] must match the arriving train.
///
/// Positions are fractions [0,1] of the board dimensions.
class NetworkNode {
  final String id;
  final double relX;
  final double relY;
  final NodeType type;
  final TrainColor? stationColor;
  final List<String> exitIds;
  int activeExit; // 0 or 1, toggled by the player (forks only)

  NetworkNode({
    required this.id,
    required this.relX,
    required this.relY,
    required this.type,
    this.stationColor,
    List<String>? exitIds,
    this.activeExit = 0,
  }) : exitIds = exitIds ?? const [];

  bool get isFork    => type == NodeType.fork;
  bool get isStation => type == NodeType.station;
  bool get isTunnel  => type == NodeType.tunnel;

  NetworkNode clone() => NetworkNode(
        id: id, relX: relX, relY: relY, type: type,
        stationColor: stationColor,
        exitIds: List<String>.from(exitIds),
        activeExit: activeExit,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Train state
// ─────────────────────────────────────────────────────────────────────────────

/// One live train on the network.
///
/// Always sits on edge [fromId] → [toId].
/// [t] ∈ [0,1]: progress along that edge (0 = at fromId, 1 = reached toId).
class TrainState {
  final int    uid;
  final TrainColor color;
  String fromId;
  String toId;
  double t;
  bool   done;
  bool   correct;

  TrainState({
    required this.uid,
    required this.color,
    required this.fromId,
    required this.toId,
    this.t       = 0.0,
    this.done    = false,
    this.correct = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Level configuration
// ─────────────────────────────────────────────────────────────────────────────

class LevelConfig {
  final Map<String, NetworkNode> nodes;
  final String tunnelId;
  final List<TrainColor> spawnSequence;
  final double trainSpeed;    // relative-units / second
  final double spawnInterval; // seconds between successive spawns
  final int allowedMistakes;

  LevelConfig({
    required this.nodes,
    required this.tunnelId,
    required this.spawnSequence,
    required this.trainSpeed,
    required this.spawnInterval,
    this.allowedMistakes = 3,
  });

  /// Returns a deep copy so each play-session has its own mutable node states.
  LevelConfig copyForPlay() => LevelConfig(
        nodes: {for (final e in nodes.entries) e.key: e.value.clone()},
        tunnelId: tunnelId,
        spawnSequence: spawnSequence,
        trainSpeed: trainSpeed,
        spawnInterval: spawnInterval,
        allowedMistakes: allowedMistakes,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Level factory
// ─────────────────────────────────────────────────────────────────────────────

class LevelFactory {
  LevelFactory._();

  static LevelConfig build(int level) {
    final idx  = (level - 1).clamp(0, _tpl.length - 1);
    final base = _tpl[idx]();
    final cycle = (level - 1) ~/ _tpl.length;
    return LevelConfig(
      nodes: base.nodes,
      tunnelId: base.tunnelId,
      spawnSequence: base.spawnSequence,
      trainSpeed:    (base.trainSpeed    + cycle * 0.025).clamp(0.10, 0.36),
      spawnInterval: (base.spawnInterval - cycle * 0.25 ).clamp(1.30, 5.0),
      allowedMistakes: base.allowedMistakes,
    );
  }

  static final List<LevelConfig Function()> _tpl = [
    _l1, _l2, _l3, _l4, _l5,
  ];

  // ── node builder shorthand ─────────────────────────────────────────────────

  static Map<String, NetworkNode> _mk(
    List<(String, double, double, NodeType, TrainColor?, List<String>)> rows,
  ) {
    final m = <String, NetworkNode>{};
    for (final r in rows) {
      m[r.$1] = NetworkNode(
        id: r.$1, relX: r.$2, relY: r.$3,
        type: r.$4, stationColor: r.$5, exitIds: r.$6,
      );
    }
    return m;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // L1 — one fork, two stations
  //
  //  [tunnel] ────────── [fork0] ─┬─ [st_blue]  (top)
  //                                └─ [st_red]   (bottom)
  // ─────────────────────────────────────────────────────────────────────────
  static LevelConfig _l1() => LevelConfig(
        nodes: _mk([
          ('tunnel',  0.06, 0.50, NodeType.tunnel,  null,              ['fork0']),
          ('fork0',   0.50, 0.50, NodeType.fork,    null,              ['st_blue', 'st_red']),
          ('st_blue', 0.92, 0.25, NodeType.station, TrainColor.blue,   []),
          ('st_red',  0.92, 0.75, NodeType.station, TrainColor.red,    []),
        ]),
        tunnelId: 'tunnel',
        spawnSequence: [
          TrainColor.blue, TrainColor.red,
          TrainColor.blue, TrainColor.red,
          TrainColor.blue, TrainColor.red,
        ],
        trainSpeed: 0.14,
        spawnInterval: 4.2,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // L2 — two forks, four stations
  //
  //                        ┌─ [fork1] ─┬─ [st_blue]
  //  [tunnel] ── [fork0] ──┤           └─ [st_pink]
  //                        └─ [fork2] ─┬─ [st_green]
  //                                    └─ [st_yellow]
  // ─────────────────────────────────────────────────────────────────────────
  static LevelConfig _l2() => LevelConfig(
        nodes: _mk([
          ('tunnel',    0.06, 0.50, NodeType.tunnel,  null,               ['fork0']),
          ('fork0',     0.33, 0.50, NodeType.fork,    null,               ['fork1', 'fork2']),
          ('fork1',     0.63, 0.28, NodeType.fork,    null,               ['st_blue', 'st_pink']),
          ('fork2',     0.63, 0.72, NodeType.fork,    null,               ['st_green', 'st_yellow']),
          ('st_blue',   0.93, 0.12, NodeType.station, TrainColor.blue,    []),
          ('st_pink',   0.93, 0.44, NodeType.station, TrainColor.pink,    []),
          ('st_green',  0.93, 0.56, NodeType.station, TrainColor.green,   []),
          ('st_yellow', 0.93, 0.88, NodeType.station, TrainColor.yellow,  []),
        ]),
        tunnelId: 'tunnel',
        spawnSequence: [
          TrainColor.blue,   TrainColor.yellow,
          TrainColor.pink,   TrainColor.green,
          TrainColor.blue,   TrainColor.green,
          TrainColor.yellow, TrainColor.pink,
        ],
        trainSpeed: 0.16,
        spawnInterval: 3.5,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // L3 — three forks, five stations (asymmetric)
  //
  //                        ┌─ [fork1] ─┬─ [fork3] ─┬─ [st_blue]
  //  [tunnel] ── [fork0] ──┤           │            └─ [st_red]
  //                        │           └─ [st_pink]
  //                        └─ [fork2] ─┬─ [st_green]
  //                                    └─ [st_yellow]
  // ─────────────────────────────────────────────────────────────────────────
  static LevelConfig _l3() => LevelConfig(
        nodes: _mk([
          ('tunnel',    0.06, 0.50, NodeType.tunnel,  null,               ['fork0']),
          ('fork0',     0.28, 0.50, NodeType.fork,    null,               ['fork1', 'fork2']),
          ('fork1',     0.54, 0.27, NodeType.fork,    null,               ['fork3', 'st_pink']),
          ('fork2',     0.54, 0.73, NodeType.fork,    null,               ['st_green', 'st_yellow']),
          ('fork3',     0.76, 0.11, NodeType.fork,    null,               ['st_blue', 'st_red']),
          ('st_blue',   0.94, 0.03, NodeType.station, TrainColor.blue,    []),
          ('st_red',    0.94, 0.19, NodeType.station, TrainColor.red,     []),
          ('st_pink',   0.93, 0.42, NodeType.station, TrainColor.pink,    []),
          ('st_green',  0.93, 0.61, NodeType.station, TrainColor.green,   []),
          ('st_yellow', 0.93, 0.93, NodeType.station, TrainColor.yellow,  []),
        ]),
        tunnelId: 'tunnel',
        spawnSequence: [
          TrainColor.blue,   TrainColor.yellow, TrainColor.red,
          TrainColor.pink,   TrainColor.green,  TrainColor.blue,
          TrainColor.yellow, TrainColor.pink,   TrainColor.red,
          TrainColor.green,
        ],
        trainSpeed: 0.18,
        spawnInterval: 2.8,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // L4 — four forks, six stations (full 2-level binary tree)
  //
  //                        ┌─ [fork1] ─┬─ [fork3] ─┬─ [st_blue]
  //  [tunnel] ── [fork0] ──┤           │            └─ [st_red]
  //                        │           └─ [st_pink]
  //                        └─ [fork2] ─┬─ [st_green]
  //                                    └─ [fork4] ─┬─ [st_yellow]
  //                                                 └─ [st_white]
  // ─────────────────────────────────────────────────────────────────────────
  static LevelConfig _l4() => LevelConfig(
        nodes: _mk([
          ('tunnel',    0.06, 0.50, NodeType.tunnel,  null,               ['fork0']),
          ('fork0',     0.26, 0.50, NodeType.fork,    null,               ['fork1', 'fork2']),
          ('fork1',     0.50, 0.27, NodeType.fork,    null,               ['fork3', 'st_pink']),
          ('fork2',     0.50, 0.73, NodeType.fork,    null,               ['st_green', 'fork4']),
          ('fork3',     0.74, 0.13, NodeType.fork,    null,               ['st_blue', 'st_red']),
          ('fork4',     0.74, 0.87, NodeType.fork,    null,               ['st_yellow', 'st_white']),
          ('st_blue',   0.94, 0.04, NodeType.station, TrainColor.blue,    []),
          ('st_red',    0.94, 0.22, NodeType.station, TrainColor.red,     []),
          ('st_pink',   0.94, 0.41, NodeType.station, TrainColor.pink,    []),
          ('st_green',  0.94, 0.59, NodeType.station, TrainColor.green,   []),
          ('st_yellow', 0.94, 0.78, NodeType.station, TrainColor.yellow,  []),
          ('st_white',  0.94, 0.96, NodeType.station, TrainColor.white,   []),
        ]),
        tunnelId: 'tunnel',
        spawnSequence: [
          TrainColor.blue,   TrainColor.white,  TrainColor.pink,
          TrainColor.green,  TrainColor.red,    TrainColor.yellow,
          TrainColor.blue,   TrainColor.white,  TrainColor.pink,
          TrainColor.red,    TrainColor.green,  TrainColor.yellow,
        ],
        trainSpeed: 0.20,
        spawnInterval: 2.3,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // L5 — same tree as L4 but faster, more trains
  // ─────────────────────────────────────────────────────────────────────────
  static LevelConfig _l5() => LevelConfig(
        nodes: _mk([
          ('tunnel',    0.06, 0.50, NodeType.tunnel,  null,               ['fork0']),
          ('fork0',     0.26, 0.50, NodeType.fork,    null,               ['fork1', 'fork2']),
          ('fork1',     0.50, 0.27, NodeType.fork,    null,               ['fork3', 'st_pink']),
          ('fork2',     0.50, 0.73, NodeType.fork,    null,               ['st_green', 'fork4']),
          ('fork3',     0.74, 0.13, NodeType.fork,    null,               ['st_blue', 'st_red']),
          ('fork4',     0.74, 0.87, NodeType.fork,    null,               ['st_yellow', 'st_white']),
          ('st_blue',   0.94, 0.04, NodeType.station, TrainColor.blue,    []),
          ('st_red',    0.94, 0.22, NodeType.station, TrainColor.red,     []),
          ('st_pink',   0.94, 0.41, NodeType.station, TrainColor.pink,    []),
          ('st_green',  0.94, 0.59, NodeType.station, TrainColor.green,   []),
          ('st_yellow', 0.94, 0.78, NodeType.station, TrainColor.yellow,  []),
          ('st_white',  0.94, 0.96, NodeType.station, TrainColor.white,   []),
        ]),
        tunnelId: 'tunnel',
        spawnSequence: [
          TrainColor.blue,   TrainColor.white,  TrainColor.pink,
          TrainColor.green,  TrainColor.red,    TrainColor.yellow,
          TrainColor.blue,   TrainColor.green,  TrainColor.white,
          TrainColor.pink,   TrainColor.red,    TrainColor.yellow,
          TrainColor.blue,   TrainColor.yellow,
        ],
        trainSpeed: 0.25,
        spawnInterval: 1.9,
      );
}
