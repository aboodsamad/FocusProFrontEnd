// ─────────────────────────────────────────────────────────────────────────────
// Enums & Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Train / station color palette (matches Lumosity palette)
enum TrainColor { blue, pink, red, green, yellow, white, purple }

enum MoveDir { up, down, left, right }

/// Each cardinal port of a grid cell
enum Port { top, bottom, left, right }

// ─────────────────────────────────────────────────────────────────────────────
// TrackCell
// ─────────────────────────────────────────────────────────────────────────────

/// A single cell in the grid.
///
/// Regular track: one [connections] entry, no toggle.
/// Junction: two [connections] entries; [activeIdx] selects the live path.
/// Station: [stationColor] set, no connections (terminal).
class TrackCell {
  final bool isJunction;
  final List<({Port a, Port b})> connections;
  int activeIdx; // 0 or 1 – only meaningful for junctions

  final TrainColor? stationColor;

  TrackCell._({
    required this.isJunction,
    required this.connections,
    this.activeIdx = 0,
    this.stationColor,
  });

  // ── Factories ──────────────────────────────────────────────────────────────

  factory TrackCell.empty() => TrackCell._(
        isJunction: false,
        connections: const [],
      );

  factory TrackCell.straight(Port a, Port b) => TrackCell._(
        isJunction: false,
        connections: [(a: a, b: b)],
      );

  /// Junction: two alternate connection pairs.
  /// Mode [activeIdx==0] uses (a0↔b0), mode [activeIdx==1] uses (a1↔b1).
  factory TrackCell.junction(
    Port a0,
    Port b0,
    Port a1,
    Port b1, {
    int activeIdx = 0,
  }) =>
      TrackCell._(
        isJunction: true,
        connections: [(a: a0, b: b0), (a: a1, b: b1)],
        activeIdx: activeIdx,
      );

  factory TrackCell.station(TrainColor color) => TrackCell._(
        isJunction: false,
        connections: const [],
        stationColor: color,
      );

  bool get isEmpty => connections.isEmpty && stationColor == null;
  bool get isStation => stationColor != null;

  /// Resolves the exit port given an [entryPort].
  /// Returns null if the entry port is not part of the active connection.
  Port? exitPort(Port entryPort) {
    final conn = connections[isJunction ? activeIdx : 0];
    if (conn.a == entryPort) return conn.b;
    if (conn.b == entryPort) return conn.a;
    return null;
  }

  void toggleJunction() {
    if (isJunction) activeIdx = 1 - activeIdx;
  }

  TrackCell copyWith({int? activeIdx}) => TrackCell._(
        isJunction: isJunction,
        connections: connections,
        activeIdx: activeIdx ?? this.activeIdx,
        stationColor: stationColor,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Train
// ─────────────────────────────────────────────────────────────────────────────

class Train {
  final TrainColor color;
  int row;
  int col;
  MoveDir direction;
  bool alive;
  bool arrived;   // reached correct station
  bool crashed;   // reached wrong station or derailed

  Train({
    required this.color,
    required this.row,
    required this.col,
    required this.direction,
    this.alive = true,
    this.arrived = false,
    this.crashed = false,
  });

  Train copyWith({
    int? row,
    int? col,
    MoveDir? direction,
    bool? alive,
    bool? arrived,
    bool? crashed,
  }) =>
      Train(
        color: color,
        row: row ?? this.row,
        col: col ?? this.col,
        direction: direction ?? this.direction,
        alive: alive ?? this.alive,
        arrived: arrived ?? this.arrived,
        crashed: crashed ?? this.crashed,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Definition
// ─────────────────────────────────────────────────────────────────────────────

class LevelDef {
  final int rows;
  final int cols;
  final List<List<TrackCell>> grid;
  final List<Train> trains;
  final Duration tickInterval;

  const LevelDef({
    required this.rows,
    required this.cols,
    required this.grid,
    required this.trains,
    required this.tickInterval,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Game State
// ─────────────────────────────────────────────────────────────────────────────

enum GamePhase { idle, playing, levelComplete, gameOver }

class TrainOfThoughtState {
  final int level;
  final int correct;       // trains delivered to correct station
  final int total;         // total trains that have finished (correct or not)
  final int mistakes;      // trains delivered to WRONG station
  final GamePhase phase;
  final List<List<TrackCell>> grid;
  final List<Train> trains;
  final int rows;
  final int cols;
  final Duration tickInterval;

  // Stars: perfect = 3, one mistake = 2, else = 1
  int get stars => mistakes == 0 ? 3 : mistakes == 1 ? 2 : 1;

  const TrainOfThoughtState({
    required this.level,
    required this.correct,
    required this.total,
    required this.mistakes,
    required this.phase,
    required this.grid,
    required this.trains,
    required this.rows,
    required this.cols,
    required this.tickInterval,
  });

  bool get isLevelDone => trains.isNotEmpty && trains.every((t) => !t.alive);

  TrainOfThoughtState copyWith({
    int? level,
    int? correct,
    int? total,
    int? mistakes,
    GamePhase? phase,
    List<List<TrackCell>>? grid,
    List<Train>? trains,
    Duration? tickInterval,
  }) =>
      TrainOfThoughtState(
        level: level ?? this.level,
        correct: correct ?? this.correct,
        total: total ?? this.total,
        mistakes: mistakes ?? this.mistakes,
        phase: phase ?? this.phase,
        grid: grid ?? this.grid,
        trains: trains ?? this.trains,
        rows: rows,
        cols: cols,
        tickInterval: tickInterval ?? this.tickInterval,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Factory
// ─────────────────────────────────────────────────────────────────────────────

class LevelFactory {
  LevelFactory._();

  static LevelDef buildLevel(int level) {
    final idx = ((level - 1) % _templates.length);
    final template = _templates[idx];

    final cycle = (level - 1) ~/ _templates.length;
    final speedUpMs = cycle * 70;
    final rawMs = template.tickInterval.inMilliseconds - speedUpMs;
    final clampedMs = rawMs.clamp(260, 1200);

    return LevelDef(
      rows: template.rows,
      cols: template.cols,
      grid: _deepCopyGrid(template.grid),
      trains: template.trains.map((t) => t.copyWith()).toList(),
      tickInterval: Duration(milliseconds: clampedMs),
    );
  }

  static List<List<TrackCell>> _deepCopyGrid(List<List<TrackCell>> src) =>
      src.map((row) => row.map((c) => c.copyWith()).toList()).toList();

  static final List<LevelDef> _templates = [
    _level1(),
    _level2(),
    _level3(),
    _level4(),
    _level5(),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 1 – Two trains, one junction
  //
  // Grid 9 × 7
  //
  // Col:  0  1  2  3  4  5  6  7  8
  // Row 0:                  V               ← Blue enters from top at col 5
  // Row 1:                  V
  // Row 2:                  V
  // Row 3: →  →  →  →  →  [J] →  →  [Rs]  ← Red station (3,8)
  // Row 4:                  V
  // Row 5:                  V
  // Row 6:                 [Bs]             ← Blue station (6,5)
  //
  // Red  starts at (3,0) going RIGHT  → arrives at junction (3,5) at tick 5
  // Blue starts at (0,5) going DOWN   → arrives at junction (3,5) at tick 3
  //
  // Blue arrives FIRST.  Junction starts V (mode 1) → blue passes straight down.
  // Player must toggle to H (mode 0) before red arrives (margin = 2 ticks).
  // ──────────────────────────────────────────────────────────────────────────
  static LevelDef _level1() {
    const r = 7;
    const c = 9;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junction at (3,5): mode H = left↔right, mode V = top↔bottom
      if (row == 3 && col == 5) {
        return TrackCell.junction(
          Port.left, Port.right,
          Port.top, Port.bottom,
          activeIdx: 1, // start V so blue (which arrives first) passes through
        );
      }
      // Stations
      if (row == 3 && col == 8) return TrackCell.station(TrainColor.red);
      if (row == 6 && col == 5) return TrackCell.station(TrainColor.blue);
      // Red horizontal track: row 3, cols 0‥7
      if (row == 3 && col >= 0 && col <= 7) return TrackCell.straight(Port.left, Port.right);
      // Blue vertical track: col 5, rows 0‥5
      if (col == 5 && row >= 0 && row <= 5) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,  row: 3, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.blue, row: 0, col: 5, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 900),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 2 – Three trains, two junctions
  //
  // Grid 9 × 8
  //
  // Col:  0  1  2  3  4  5  6  7  8
  // Row 0:          V           V          ← Green(0,2) and Yellow(0,6)
  // Row 1:          V           V
  // Row 2:          V           V
  // Row 3: →  →  →[J1]→  →  →[J2]→  [Rs]  ← Red (3,0)→right; stations
  // Row 4:          V           V
  // Row 5:          V           V
  // Row 6:          V           V
  // Row 7:         [Gs]        [Ys]
  //
  // J1 at (3,3): mode H → red; mode V → green (arrives tick 3, red tick 3)
  //   Green starts (0,3), arrives tick 3; Red starts (3,0), arrives tick 3 – same!
  //   Fix: Red starts (3,0), Green starts (0,2). Red tick to J1=3, Green tick=3. BAD.
  //   Use J1 at (3,4): Red tick=4, Green at (0,4) tick=3. Green first, margin=1.
  //
  // Revised columns for junctions:
  //   J1 at (3,3): Red arrives tick 3, Green at (0,2) arrives tick 3 – bad.
  //   Use Green col 2: row 0‥row 3 = 3 ticks; Red at col 0 row 3 to col 3 = 3 ticks. Same again!
  //
  //   Final fix: stagger starts.
  //   J1 at (3,2):  Red start (3,0) → tick=2; Green start (0,2) → tick=3. Red first, margin=1.
  //   J2 at (3,6):  Red continues from (3,3) → tick=6-3=3 more → tick=5 total; Yellow (0,6) → tick=3.
  //                 Yellow arrives first (tick 3), margin=2.
  // ──────────────────────────────────────────────────────────────────────────
  static LevelDef _level2() {
    const r = 8;
    const c = 9;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // J1 at (3,2): H for red, V for green. Red arrives tick=2, green tick=3. Start H.
      if (row == 3 && col == 2) {
        return TrackCell.junction(
          Port.left, Port.right,
          Port.top, Port.bottom,
          activeIdx: 0, // H – red arrives first
        );
      }
      // J2 at (3,6): H for red, V for yellow. Yellow arrives tick=3, red tick=6. Start V.
      if (row == 3 && col == 6) {
        return TrackCell.junction(
          Port.left, Port.right,
          Port.top, Port.bottom,
          activeIdx: 1, // V – yellow arrives first
        );
      }
      // Stations
      if (row == 3 && col == 8) return TrackCell.station(TrainColor.red);
      if (row == 7 && col == 2) return TrackCell.station(TrainColor.green);
      if (row == 7 && col == 6) return TrackCell.station(TrainColor.yellow);
      // Red horizontal track: row 3, cols 0‥7
      if (row == 3 && col >= 0 && col <= 7) return TrackCell.straight(Port.left, Port.right);
      // Green vertical: col 2, rows 0‥6
      if (col == 2 && row >= 0 && row <= 6) return TrackCell.straight(Port.top, Port.bottom);
      // Yellow vertical: col 6, rows 0‥6
      if (col == 6 && row >= 0 && row <= 6) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,    row: 3, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green,  row: 0, col: 2, direction: MoveDir.down),
      Train(color: TrainColor.yellow, row: 0, col: 6, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 780),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 3 – Three trains, three junctions, CURVE tracks
  //
  // Two horizontal trains + one vertical + curve junctions that bend the path.
  //
  // Grid 10 × 8
  //
  // Col:  0  1  2  3  4  5  6  7  8  9
  // Row 0:               Bl             ← Blue enters (0,4) going DOWN
  // Row 1:               V
  // Row 2:    R1 →→→→→→ [J1]→→→→→ [Rs] ← Red enters (2,1) RIGHT, junction at (2,4)
  // Row 3:               V
  // Row 4:    R2 →→→→→→ [J2]→→→→→ [Ps] ← Pink enters (4,1) RIGHT, junction at (4,4)
  // Row 5:               V
  // Row 6:               V
  // Row 7:              [Bs]             ← Blue station (7,4)
  //
  // J1 at (2,4): H → red goes right; V → blue goes through (downward)
  //   Red arrives tick=3, Blue arrives tick=2. Blue first → start V. Toggle to H, margin=1.
  //
  // J2 at (4,4): H → pink goes right; V → blue continues down.
  //   Pink arrives tick=3, Blue arrives tick=4 (from J1 at row 2, continues row3, row4). Blue second!
  //   Pink first → start H. Toggle to V before blue arrives (margin=1).
  //
  // Pink station at (4,9), Red station at (2,9), Blue station at (7,4)
  // ──────────────────────────────────────────────────────────────────────────
  static LevelDef _level3() {
    const r = 8;
    const c = 10;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // J1 at (2,4): H=left↔right, V=top↔bottom. Start V (blue arrives first tick=2).
      if (row == 2 && col == 4) {
        return TrackCell.junction(
          Port.left, Port.right,
          Port.top, Port.bottom,
          activeIdx: 1,
        );
      }
      // J2 at (4,4): H=left↔right, V=top↔bottom. Start H (pink arrives first tick=3).
      if (row == 4 && col == 4) {
        return TrackCell.junction(
          Port.left, Port.right,
          Port.top, Port.bottom,
          activeIdx: 0,
        );
      }
      // Stations
      if (row == 2 && col == 9) return TrackCell.station(TrainColor.red);
      if (row == 4 && col == 9) return TrackCell.station(TrainColor.pink);
      if (row == 7 && col == 4) return TrackCell.station(TrainColor.blue);
      // Red horizontal: row 2, cols 1‥8
      if (row == 2 && col >= 1 && col <= 8) return TrackCell.straight(Port.left, Port.right);
      // Pink horizontal: row 4, cols 1‥8
      if (row == 4 && col >= 1 && col <= 8) return TrackCell.straight(Port.left, Port.right);
      // Blue vertical: col 4, rows 0‥6
      if (col == 4 && row >= 0 && row <= 6) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,  row: 2, col: 1, direction: MoveDir.right),
      Train(color: TrainColor.pink, row: 4, col: 1, direction: MoveDir.right),
      Train(color: TrainColor.blue, row: 0, col: 4, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 660),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 4 – Four trains, four junctions, denser network
  //
  // Grid 10 × 9
  //
  // Two horizontal tracks (rows 2 and 6) + two vertical tracks (cols 3 and 7).
  // Four junctions at intersections.
  //
  // Col:  0  1  2  3  4  5  6  7  8  9
  // Row 0:          G1          G2          ← Green(0,3) and Yellow(0,7) enter
  // Row 1:          V           V
  // Row 2: R1→ →  →[J1]→ → →  [J2]→  [Rs] ← Red enters (2,0)
  // Row 3:          V           V
  // Row 4:          V           V
  // Row 5:          V           V
  // Row 6: R2→ →  →[J3]→ → →  [J4]→  [Ps] ← Pink enters (6,0)
  // Row 7:          V           V
  // Row 8:         [Gs]        [Ys]
  //
  // J1 (2,3): Red tick=3, Green tick=2. Green first → start V. Toggle H for red (margin=1).
  // J2 (2,7): Red tick=7, Yellow tick=2. Yellow first → start V. Toggle H for red (margin=5).
  // J3 (6,3): Pink tick=3, Green tick=6. Pink first → start H. Toggle V for green (margin=3).
  // J4 (6,7): Pink tick=7, Yellow tick=6. Yellow first → start V. Toggle H for pink (margin=1).
  // ──────────────────────────────────────────────────────────────────────────
  static LevelDef _level4() {
    const r = 9;
    const c = 10;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junctions
      if (row == 2 && col == 3) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // V (green first)
      if (row == 2 && col == 7) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // V (yellow first)
      if (row == 6 && col == 3) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // H (pink first)
      if (row == 6 && col == 7) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // V (yellow first)
      // Stations
      if (row == 2 && col == 9) return TrackCell.station(TrainColor.red);
      if (row == 6 && col == 9) return TrackCell.station(TrainColor.pink);
      if (row == 8 && col == 3) return TrackCell.station(TrainColor.green);
      if (row == 8 && col == 7) return TrackCell.station(TrainColor.yellow);
      // Red horizontal: row 2, cols 0‥8
      if (row == 2 && col >= 0 && col <= 8) return TrackCell.straight(Port.left, Port.right);
      // Pink horizontal: row 6, cols 0‥8
      if (row == 6 && col >= 0 && col <= 8) return TrackCell.straight(Port.left, Port.right);
      // Green vertical: col 3, rows 0‥7
      if (col == 3 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Yellow vertical: col 7, rows 0‥7
      if (col == 7 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,    row: 2, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.pink,   row: 6, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green,  row: 0, col: 3, direction: MoveDir.down),
      Train(color: TrainColor.yellow, row: 0, col: 7, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 560),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 5 – Five trains, five junctions, maximum complexity
  //
  // Three horizontal + two vertical, five junctions (including one extra mid-
  // network junction to force rapid switching)
  //
  // Grid 11 × 10
  //
  // Col:  0  1  2  3  4  5  6  7  8  9  10
  // Row 0:          G1    Wh          G2       ← Green(0,2), White(0,4), extra vertical
  // Row 1:          V     V           V
  // Row 2: R →→→→ [J1]→ [J5] → →  →[J2] → [Rs]  ← Red (2,0)
  // Row 3:          V     V           V
  // Row 4:          V     V           V
  // Row 5: P →→→→ [J3] → → → → →→  [J4] → [Ps]  ← Pink (5,0)
  // Row 6:          V                 V
  // Row 7:          V                 V
  // Row 8:         [Gs]              [Ws]
  // Row 9:               [Bs]
  //
  // This is complex – simplify: 5 trains, 5 junctions in a tight 10×9 grid.
  // Blue enters from bottom row going UP so we have a third axis.
  // ──────────────────────────────────────────────────────────────────────────
  static LevelDef _level5() {
    const r = 9;
    const c = 11;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // 5 junctions
      if (row == 2 && col == 3)  return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1);
      if (row == 2 && col == 7)  return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1);
      if (row == 5 && col == 3)  return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      if (row == 5 && col == 7)  return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1);
      if (row == 5 && col == 5)  return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      // Stations
      if (row == 2 && col == 10) return TrackCell.station(TrainColor.red);
      if (row == 5 && col == 10) return TrackCell.station(TrainColor.pink);
      if (row == 8 && col == 3)  return TrackCell.station(TrainColor.green);
      if (row == 8 && col == 7)  return TrackCell.station(TrainColor.yellow);
      if (row == 8 && col == 5)  return TrackCell.station(TrainColor.blue);
      // Red horizontal: row 2, cols 0‥9
      if (row == 2 && col >= 0 && col <= 9) return TrackCell.straight(Port.left, Port.right);
      // Pink horizontal: row 5, cols 0‥9
      if (row == 5 && col >= 0 && col <= 9) return TrackCell.straight(Port.left, Port.right);
      // Green vertical: col 3, rows 0‥7
      if (col == 3 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Yellow vertical: col 7, rows 0‥7
      if (col == 7 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Blue vertical: col 5, rows 0‥7
      if (col == 5 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,    row: 2, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.pink,   row: 5, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green,  row: 0, col: 3, direction: MoveDir.down),
      Train(color: TrainColor.yellow, row: 0, col: 7, direction: MoveDir.down),
      Train(color: TrainColor.blue,   row: 0, col: 5, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 460),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Direction helpers
// ─────────────────────────────────────────────────────────────────────────────

extension MoveDirExt on MoveDir {
  /// The port a train enters when moving in this direction
  Port get entryPort {
    switch (this) {
      case MoveDir.right: return Port.left;
      case MoveDir.left:  return Port.right;
      case MoveDir.down:  return Port.top;
      case MoveDir.up:    return Port.bottom;
    }
  }

  int get dRow {
    switch (this) {
      case MoveDir.down:  return 1;
      case MoveDir.up:    return -1;
      default:            return 0;
    }
  }

  int get dCol {
    switch (this) {
      case MoveDir.right: return 1;
      case MoveDir.left:  return -1;
      default:            return 0;
    }
  }
}

extension PortExt on Port {
  MoveDir get exitDir {
    switch (this) {
      case Port.right:  return MoveDir.right;
      case Port.left:   return MoveDir.left;
      case Port.bottom: return MoveDir.down;
      case Port.top:    return MoveDir.up;
    }
  }
}
