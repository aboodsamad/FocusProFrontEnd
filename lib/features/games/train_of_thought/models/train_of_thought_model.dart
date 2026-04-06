
// ─────────────────────────────────────────────────────────────────────────────
// Enums & Constants
// ─────────────────────────────────────────────────────────────────────────────

enum TrainColor { red, blue, green, yellow }

enum MoveDir { up, down, left, right }

// Each port of a cell
enum Port { top, bottom, left, right }

// ─────────────────────────────────────────────────────────────────────────────
// TrackCell
// ─────────────────────────────────────────────────────────────────────────────

/// A single cell in the grid.
/// [connections] lists the port-pairs that are connected.
/// Non-junction cells have exactly one entry in [connections].
/// Junction cells have exactly two entries; [activeIdx] selects which is active.
class TrackCell {
  final bool isJunction;
  final List<({Port a, Port b})> connections;
  int activeIdx; // 0 or 1 (only meaningful for junctions)

  // Station data
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

  /// Given that a train enters from [entryPort], returns the exit port.
  /// Returns null if the cell cannot route this train (wrong track / station / empty).
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
  bool alive; // still moving
  bool arrived; // reached correct station (success)
  bool crashed; // reached wrong station (mistake counted)

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
  final List<List<TrackCell>> grid; // [row][col]
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
  final int score;
  final int mistakes;
  final GamePhase phase;
  final List<List<TrackCell>> grid;
  final List<Train> trains;
  final int rows;
  final int cols;
  final Duration tickInterval;

  // Stars: 3 = 0 mistakes, 2 = 1 mistake, 1 = 2 mistakes
  int get stars => mistakes == 0 ? 3 : mistakes == 1 ? 2 : 1;

  const TrainOfThoughtState({
    required this.level,
    required this.score,
    required this.mistakes,
    required this.phase,
    required this.grid,
    required this.trains,
    required this.rows,
    required this.cols,
    required this.tickInterval,
  });

  bool get isLevelDone =>
      trains.isNotEmpty && trains.every((t) => !t.alive);

  TrainOfThoughtState copyWith({
    int? level,
    int? score,
    int? mistakes,
    GamePhase? phase,
    List<List<TrackCell>>? grid,
    List<Train>? trains,
    Duration? tickInterval,
  }) =>
      TrainOfThoughtState(
        level: level ?? this.level,
        score: score ?? this.score,
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

/// Builds pre-defined and procedurally extended levels.
class LevelFactory {
  LevelFactory._();

  static LevelDef buildLevel(int level) {
    // Clamp to pre-defined levels, then scale difficulty
    final idx = ((level - 1) % _templates.length);
    final template = _templates[idx];

    // Speed up every template cycle
    final speedUp = Duration(
      milliseconds: ((level - 1) ~/ _templates.length) * 80,
    );
    final rawMs = template.tickInterval.inMilliseconds - speedUp.inMilliseconds;
    final clampedMs = rawMs.clamp(280, 1400);

    return LevelDef(
      rows: template.rows,
      cols: template.cols,
      grid: _deepCopyGrid(template.grid),
      trains: template.trains.map((t) => t.copyWith()).toList(),
      tickInterval: Duration(milliseconds: clampedMs),
    );
  }

  // ── Deep copy helper ───────────────────────────────────────────────────────

  static List<List<TrackCell>> _deepCopyGrid(List<List<TrackCell>> src) {
    return src
        .map((row) => row.map((cell) => cell.copyWith()).toList())
        .toList();
  }

  // ── Template list ──────────────────────────────────────────────────────────

  static final List<LevelDef> _templates = [
    _level1(),
    _level2(),
    _level3(),
    _level4(),
    _level5(),
  ];

  // ---------------------------------------------------------------------------
  // Level 1: Two trains, two junctions, slow
  // Red train comes from left on row 2 → should reach red station (right, row 2)
  // Blue train comes from top on col 4 → should reach blue station (bottom, col 4)
  // They cross, one junction decides who goes where
  //
  // Grid (7 cols × 9 rows), rows 0-8, cols 0-6
  //
  //  . . . . . . .
  //  . . . . V . .
  //  R H H J H H G   ← red enters left col0 row2, junction at col3
  //  . . . . V . .
  //  . . . . V . .
  //  . . . . V . .
  //  . . . . V . .
  //  . . . . V . .
  //  . . . . B . .   ← blue station bottom col4
  //
  // Wait, if junction is at col3 row2 mode H, red passes through to col6 = green station (wrong!)
  // Let me redesign this.
  //
  // Level 1 simple:
  // Red train enters from left on row 3, wants red station on right row 3.
  // Blue train enters from top on col 3, wants blue station on bottom col 3.
  // They cross at col 3, row 3. A junction there decides routing.
  // Default junction = H → red passes through (correct), blue gets deflected...
  // Actually I need to think about this more carefully.
  //
  // Let me just do two completely separate tracks for level 1.
  // Red: enters left row 2, straight H to right where red station is
  // Blue: enters top col 4, straight V to bottom where blue station is
  // No junctions needed, just simple routing!
  // But then where's the challenge? We need at least 1 junction.
  //
  // Level 1 with 1 junction:
  // Red track: row 2, left → right. Starts at col 0 going right. Red station at col 6 row 2.
  // Blue track: starts at col 2 row 0 going down. Goes down to row 2, turns right to col 6.
  //   But red station is at col 6 row 2...
  //   Let's put blue station at col 6 row 5.
  //   Blue goes down col 2 → row 2. Junction at (2, 2) → if active=V, blue continues down.
  //   But red at row 2 passes through col 2 as straight H.
  //   Actually if the junction is a cross/split...
  //
  // Simpler redesign for level 1:
  // 7 cols × 7 rows
  // Red train: enters from LEFT at row 3. Goes straight right. Red station at col 6, row 3.
  //   Track: row 3, col 0..6 all H, station at col 6.
  //   But blue track needs to cross...
  //
  // Let me use this layout (7×7):
  // Row 0:  . . . B . . .    <- Blue station at col 3
  // Row 1:  . . . V . . .
  // Row 2:  . . . V . . .
  // Row 3:  R H H J H H .    <- Red enters left, junction at col 3. No red station yet.
  // Row 4:  . . . V . . .
  // Row 5:  . . . V . . .
  // Row 6:  . . . V . . R    <- Red station at col 6? No...
  //
  // Hmm, I need both trains to have clear routes to their stations.
  //
  // Let me try a different layout where the tracks share a junction:
  //
  // Level 1: 7×7 grid
  // Red train enters LEFT at row 2.
  // Blue train enters TOP at col 5.
  //
  // Track layout:
  // Row 0: . . . . . B .    Blue station at col 5, row 0 (top)... wait, train enters from top, so station would be at top?
  //
  // Actually in the original game, stations are at the EDGES. Trains start at edges and move inward.
  // The stations of matching colors are on a different edge.
  //
  // Let me redesign with entry and exit edges clearly:
  //
  // 7 cols × 7 rows
  //
  // Red train: enters from LEFT at (row 3, col -1), moving RIGHT.
  //   Red STATION at RIGHT edge: (row 3, col 7) = off-grid, so station is at (row 3, col 6).
  //   Track: all of row 3 is horizontal track.
  //
  // Blue train: enters from TOP at (row -1, col 3), moving DOWN.
  //   Blue STATION at BOTTOM edge: (row 7, col 3) → station at (row 6, col 3).
  //   Track: all of col 3 is vertical track.
  //
  // Crossing at (row 3, col 3): JUNCTION
  //   Mode H (activeIdx=0): left↔right → Red passes through, Blue is deflected
  //   Mode V (activeIdx=1): top↔bottom → Blue passes through, Red is deflected
  //
  // But if red goes through junction in mode H: red reaches (row 3, col 6) = RED STATION ✓
  // Blue in mode H: enters from top at col 3, needs to exit somewhere...
  //
  // The junction connects:
  //   Mode H: Port.left ↔ Port.right
  //   Mode V: Port.top ↔ Port.bottom
  //
  // Blue enters junction from TOP:
  //   Mode H: junction connects left↔right, so top is not connected → train derails (bad)
  //   Mode V: junction connects top↔bottom → blue exits bottom ✓
  //
  // Red enters junction from LEFT:
  //   Mode H: junction connects left↔right → red exits right ✓
  //   Mode V: junction connects top↔bottom → left not connected → train derails (bad)
  //
  // So in this layout, BOTH trains need to go through the SAME junction but one needs mode H and the other needs mode V. They can't both succeed simultaneously with a single junction!
  //
  // This means I need SEPARATE junctions for each train path, or trains need to arrive at the junction at different times.
  //
  // In the actual Train of Thought game, trains arrive at junctions at different times, and the player needs to toggle the junction BEFORE each train arrives.
  //
  // Let me redesign with timing:
  // - Red train starts at left side, has to travel 3 cells before reaching junction
  // - Blue train starts at top side, has to travel 1 cell before reaching junction
  // - Blue arrives first, then red
  //
  // And the player needs to:
  // 1. First set junction to V (for blue to pass through)
  // 2. Then toggle to H (for red to pass through)
  //
  // But wait - can the player toggle a junction while a train is on it? No, that would be weird. The toggle only matters BEFORE the train arrives.
  //
  // Actually re-reading the spec: "Junctions can be tapped to toggle direction". So the player taps before trains arrive. The challenge is anticipating WHICH train arrives at WHICH junction WHEN, and setting the junctions appropriately before each train passes.
  //
  // Now for Level 1, let me have ONE shared junction. Default state: mode H.
  // Red train: enters LEFT at row 3. Distance to junction: 3 cells. Arrives at time = 3 ticks.
  // Blue train: enters TOP at col 3. Distance to junction: 5 cells. Arrives at time = 5 ticks.
  //
  // Player strategy:
  // - Initially junction is H: good for red (arrives first at tick 3)
  // - After red passes, toggle to V before tick 5 so blue can pass
  //
  // This is the core mechanic! Let me build this.
  //
  // Level 1 grid (7×7):
  // Col:   0  1  2  3  4  5  6
  // Row 0: .  .  .  V  .  .  .
  // Row 1: .  .  .  V  .  .  .
  // Row 2: .  .  .  V  .  .  .
  // Row 3: H  H  H  J  H  H  Rs  ← Rs = Red Station, J = Junction (default H)
  // Row 4: .  .  .  V  .  .  .
  // Row 5: .  .  .  V  .  .  .
  // Row 6: .  .  .  Bs .  .  .   ← Bs = Blue Station
  //
  // Trains:
  // - Red: starts at (3, 0), direction RIGHT (but cell 0 has H track, so it starts moving from left edge)
  //   Actually train starts at col -1 (off screen), and first moves to col 0 on first tick.
  //   Let me say train starts at (3, 0) and we render it there, direction RIGHT.
  // - Blue: starts at (0, 3), direction DOWN.
  //
  // Red station at (3, 6).
  // Blue station at (6, 3).
  //
  // When red enters junction at (3, 3) mode H: exits RIGHT → continues to (3, 6) = Red station ✓
  // When blue enters junction at (3, 3) mode V: exits BOTTOM → continues to (6, 3) = Blue station ✓
  //
  // So player needs to:
  // - Start with junction in H mode (red passes at tick 3, col 0→1→2→3, then exits right)
  // - Toggle junction to V BEFORE blue reaches it (blue passes at tick 3, row 0→1→2→3)
  //
  // Wait, they arrive at the same tick! That's a problem.
  //
  // Let me offset the starting positions:
  // - Red: starts at (3, 0), 3 cells from junction (at col 3) → arrives at junction at tick 3
  // - Blue: starts at (0, 3), 3 cells from junction (at row 3) → arrives at junction at tick 3
  //
  // They arrive simultaneously → no time to toggle!
  //
  // Solution: offset starting positions:
  // - Red: starts at (3, 0) → 3 ticks to junction
  // - Blue: starts at (0, 3) → offset: start blue further away, say at row 0, which is only 3 rows from junction...
  //
  // Actually let me use a BIGGER grid (9 cols × 9 rows) and stagger the start:
  // - Red starts at (4, 0), junction at (4, 5). Red arrives at tick 5.
  // - Blue starts at (0, 5), junction at (4, 5). Blue arrives at tick 4.
  //
  // Blue arrives first. By default, junction is V (good for blue).
  // Player doesn't need to do anything for blue.
  // After blue passes, player must toggle junction to H before red arrives.
  // Red arrives 1 tick later (tick 5 vs tick 4).
  //
  // That gives exactly 1 tick margin! Let me use 2 ticks margin for level 1 (easier).
  //
  // - Red: starts at (4, 0), junction at (4, 5). Arrives at tick 5.
  // - Blue: starts at (0, 5), junction at (4, 5). Arrives at tick 3 (wait, 4 cells: 0→1→2→3→4=junction).
  //
  // Hmm 4 cells (rows 0,1,2,3) → arrives at tick 4. Red arrives at tick 5. 1 tick margin.
  //
  // For level 1 I want 2 ticks margin for easiness. Let me just use a longer blue path:
  // - Blue: starts at (0, 5). Junction at (5, 5). Arrives at tick 5.
  // - Red: starts at (5, 0). Junction at (5, 4). Arrives at tick 4.
  //
  // Now they DON'T share a junction. Different junctions.
  //
  // Ugh, this is getting complicated. Let me just define a clean, playable level 1 with simple routing and 1 junction, accepting that both trains converge at slightly different times.
  //
  // FINAL LEVEL 1 DESIGN:
  //
  // Grid: 7 cols × 9 rows
  //
  // Layout:
  // Red track: horizontal along row 4, cols 0-6
  // Blue track: vertical along col 3, rows 0-8
  // They cross at (4, 3) = junction (default H)
  // Red station at (4, 6)
  // Blue station at (8, 3)
  //
  // Red starts at (4, 0), direction RIGHT. Ticks to junction: 3
  // Blue starts at (0, 3), direction DOWN. Ticks to junction: 4
  //
  // Blue arrives first (tick 4). Junction should be V for blue.
  // But default is H...
  //
  // OK let me set DEFAULT = V, then:
  // Blue arrives at tick 4: passes through (mode V) → continues down to station ✓
  // Red arrives at tick 3: junction is V → left not connected → CRASH ✗
  //
  // Default = H:
  // Red arrives at tick 3: passes through (mode H) → continues right to station ✓
  // Blue arrives at tick 4: junction still H → top not connected → CRASH ✗
  //   UNLESS player toggles to V after red passes (between tick 3 and tick 4)
  //
  // This is the exact mechanic! Player must:
  // 1. Keep junction H for red (or not touch it)
  // 2. Toggle to V after red passes (at tick 3+) before blue arrives (at tick 4)
  //
  // With 1 tick margin, this is quite tight for level 1. Let me increase the margin.
  //
  // Make red start at (4, 1) (col 1) and blue start at (0, 3):
  // Red: ticks to junction = 2 (col 1 → 2 → 3)
  // Blue: ticks to junction = 4 (row 0 → 1 → 2 → 3 → 4)
  //
  // Wait, col 1 to junction at col 3: that's 2 cells (col 1→2→3), arrives at tick 2.
  // Blue row 0 to junction at row 4: 4 cells, arrives at tick 4. Margin = 2 ticks!
  //
  // With a 800ms tick interval (level 1), that's 1.6 seconds to toggle after red passes.
  //
  // FINAL LEVEL 1:
  // Grid: 7 cols × 9 rows
  // Red starts at (4, 1) going RIGHT. Station (4, 6).
  // Blue starts at (0, 3) going DOWN. Station (8, 3).
  // Junction at (4, 3) default H.
  // Tracks: row 4 cols 1-6 = H, col 3 rows 0-8 = V.
  // (4,3) is J default H.
  //
  // Col:  0  1  2  3  4  5  6
  // R0:   .  .  .  V  .  .  .
  // R1:   .  .  .  V  .  .  .
  // R2:   .  .  .  V  .  .  .
  // R3:   .  .  .  V  .  .  .
  // R4:   .  R  H  J  H  H  Rs  ← Rs=RedStation, R=red train start
  // R5:   .  .  .  V  .  .  .
  // R6:   .  .  .  V  .  .  .
  // R7:   .  .  .  V  .  .  .
  // R8:   .  .  .  Bs .  .  .   ← Bs=BlueStation
  //
  // Wait, I have 9 rows (0-8). Blue starts at row 0, junction at row 4. Blue needs to travel rows 0→1→2→3→4. That's arriving at tick 4.
  // Red starts at col 1, junction at col 3. Red travels cols 1→2→3. Arrives at tick 2.
  // Margin = 4-2 = 2 ticks.
  //
  // After red passes junction (tick 2), player has 2 ticks to toggle junction to V.
  // At tick 3: blue is at row 3, player should toggle by now.
  // At tick 4: blue reaches junction (row 4), needs V mode.
  //
  // After junction, red continues: col 3→4→5→6=RedStation. Arrives at tick 5.
  // After junction, blue continues: row 4→5→6→7→8=BlueStation. Arrives at tick 8.
  //
  // This looks good for level 1!
  //
  // OK now let me actually just write the code. I've been overthinking this.
  // I'll define 5 levels with increasing complexity.

  static LevelDef _level1() {
    // 7 cols × 9 rows
    // Red train: starts (4, 1) RIGHT → Red station (4, 6)
    // Blue train: starts (0, 3) DOWN → Blue station (8, 3)
    // One junction at (4, 3), default H
    const r = 9;
    const c = 7;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      if (row == 4 && col == 3) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      if (row == 4 && col == 6) return TrackCell.station(TrainColor.red);
      if (row == 8 && col == 3) return TrackCell.station(TrainColor.blue);
      if (row == 4 && col >= 1 && col <= 5) return TrackCell.straight(Port.left, Port.right);
      if (col == 3 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,  row: 4, col: 1, direction: MoveDir.right),
      Train(color: TrainColor.blue, row: 0, col: 3, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 800),
    );
  }

  static LevelDef _level2() {
    // 7 cols × 9 rows
    // Red: starts (2, 0) RIGHT → Red station (2, 6)
    // Blue: starts (0, 4) DOWN → Blue station (8, 4)
    // Green: starts (6, 0) RIGHT → Green station (6, 6)
    // Two junctions: at (2, 4) and (6, 4)
    //
    //  Col: 0  1  2  3  4  5  6
    //  R0:  .  .  .  .  V  .  .
    //  R1:  .  .  .  .  V  .  .
    //  R2:  R  H  H  H  J  H  Rs
    //  R3:  .  .  .  .  V  .  .
    //  R4:  .  .  .  .  V  .  .
    //  R5:  .  .  .  .  V  .  .
    //  R6:  G  H  H  H  J  H  Gs
    //  R7:  .  .  .  .  V  .  .
    //  R8:  .  .  .  .  Bs .  .
    //
    // Blue train goes from (0,4) down through (2,4) junction and (6,4) junction to (8,4)=Blue station.
    // Red and Green trains go straight through their rows to their stations.
    //
    // For blue to pass through (2,4): junction must be V.
    // For red to pass through (2,4): junction must be H. But red arrives before blue passes through...
    //   Red arrives at (2,4) at tick 4 (col 0→1→2→3→4).
    //   Blue arrives at (2,4) at tick 2 (row 0→1→2).
    //   Blue arrives FIRST. So junction at (2,4) should start V (blue passes), then toggle to H for red.
    //
    // For blue to pass through (6,4): junction must be V.
    // For green to pass through (6,4): junction must be H.
    //   Blue arrives at (6,4) at tick 6 (continuing from row 2→3→4→5→6).
    //   Green arrives at (6,4) at tick 4 (col 0→1→2→3→4).
    //   Green arrives FIRST. Junction at (6,4) should start H for green, then toggle to V for blue.
    //
    // Junction (2,4): start V (for blue who arrives tick 2). Toggle to H before red arrives (tick 4). Margin: 2 ticks.
    // Junction (6,4): start H (for green who arrives tick 4). Toggle to V before blue arrives (tick 6). Margin: 2 ticks.
    //
    // Nice and symmetric!

    const r = 9;
    const c = 7;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junctions
      if (row == 2 && col == 4) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // start V
      if (row == 6 && col == 4) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // start H
      // Stations
      if (row == 2 && col == 6) return TrackCell.station(TrainColor.red);
      if (row == 6 && col == 6) return TrackCell.station(TrainColor.green);
      if (row == 8 && col == 4) return TrackCell.station(TrainColor.blue);
      // Red track row 2
      if (row == 2 && col >= 0 && col <= 5) return TrackCell.straight(Port.left, Port.right);
      // Green track row 6
      if (row == 6 && col >= 0 && col <= 5) return TrackCell.straight(Port.left, Port.right);
      // Blue track col 4
      if (col == 4 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,   row: 2, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green, row: 6, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.blue,  row: 0, col: 4, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 700),
    );
  }

  static LevelDef _level3() {
    // More complex: 3 trains, 3 junctions
    // Layout: 8 cols × 9 rows
    // Red:   (4, 0) RIGHT → station (4, 7)
    // Blue:  (0, 2) DOWN  → station (8, 2)
    // Green: (0, 5) DOWN  → station (8, 5)
    //
    // Red goes across row 4.
    // Blue goes down col 2.
    // Green goes down col 5.
    //
    // Junction A at (4, 2): red/blue cross. Default H (red first, tick 2).
    // Junction B at (4, 5): red/green cross. Default H (red first, tick 5).
    // Blue arrives at (4, 2) at tick 4. Green arrives at (4, 5) at tick 4.
    //
    // Player must:
    // - Let red through at (4,2) tick=2 [default H]
    // - Toggle (4,2) to V before tick=4 for blue
    // - Let red through at (4,5) tick=5 [reset to H] - but has player re-toggled?
    // - Toggle (4,5) to V before tick=4 for green
    //
    // Wait, red arrives at (4,5) at tick 5, green at (4,5) at tick 4.
    // Green arrives first at (4,5). So (4,5) should start V for green.
    // Then toggle to H before red arrives at tick 5. Margin = 1 tick.
    //
    // Summary:
    // JuncA (4,2): start H → toggle to V after tick 2 (for blue at tick 4). Margin 2.
    // JuncB (4,5): start V → toggle to H after tick 4 (for red at tick 5). Margin 1.
    //
    // Getting harder!

    const r = 9;
    const c = 8;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junctions
      if (row == 4 && col == 2) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // start H
      if (row == 4 && col == 5) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // start V
      // Stations
      if (row == 4 && col == 7) return TrackCell.station(TrainColor.red);
      if (row == 8 && col == 2) return TrackCell.station(TrainColor.blue);
      if (row == 8 && col == 5) return TrackCell.station(TrainColor.green);
      // Red track: row 4, cols 0..6
      if (row == 4 && col >= 0 && col <= 6) return TrackCell.straight(Port.left, Port.right);
      // Blue track: col 2, rows 0..7
      if (col == 2 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Green track: col 5, rows 0..7
      if (col == 5 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,   row: 4, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.blue,  row: 0, col: 2, direction: MoveDir.down),
      Train(color: TrainColor.green, row: 0, col: 5, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 650),
    );
  }

  static LevelDef _level4() {
    // 4 trains, 4 junctions, curves involved
    // 8 cols × 9 rows
    // Red:    (4, 0) RIGHT → station (4, 7)
    // Blue:   (0, 3) DOWN  → station (8, 3)
    // Green:  (0, 6) DOWN  → curves to right, station at (4, 7)... no, stations must be unique
    //
    // Revised:
    // Red:    (3, 0) RIGHT → station (3, 7)
    // Blue:   (6, 0) RIGHT → station (6, 7)
    // Green:  (0, 2) DOWN  → station (8, 2)
    // Yellow: (0, 5) DOWN  → station (8, 5)
    //
    // Junctions:
    // (3, 2): Red/Green cross. Red tick=2, Green tick=3. Start H for red. Toggle to V for green. Margin=1.
    // (3, 5): Red/Yellow cross. Red tick=5, Yellow tick=3. Start V for yellow. Toggle to H for red. Margin=2.
    // (6, 2): Blue/Green cross. Blue tick=2, Green tick=6. Start H for blue. Toggle to V for green. Margin=4.
    // (6, 5): Blue/Yellow cross. Blue tick=5, Yellow tick=6. Start H for blue. Toggle to V for yellow. Margin=1.
    //
    // This is getting complex with 4 trains. Let me simplify slightly.

    const r = 9;
    const c = 8;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junctions
      if (row == 3 && col == 2) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // H for red
      if (row == 3 && col == 5) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1); // V for yellow
      if (row == 6 && col == 2) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // H for blue
      if (row == 6 && col == 5) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0); // H for blue
      // Stations
      if (row == 3 && col == 7) return TrackCell.station(TrainColor.red);
      if (row == 6 && col == 7) return TrackCell.station(TrainColor.blue);
      if (row == 8 && col == 2) return TrackCell.station(TrainColor.green);
      if (row == 8 && col == 5) return TrackCell.station(TrainColor.yellow);
      // Red track: row 3, cols 0..6
      if (row == 3 && col >= 0 && col <= 6) return TrackCell.straight(Port.left, Port.right);
      // Blue track: row 6, cols 0..6
      if (row == 6 && col >= 0 && col <= 6) return TrackCell.straight(Port.left, Port.right);
      // Green track: col 2, rows 0..7
      if (col == 2 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Yellow track: col 5, rows 0..7
      if (col == 5 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,    row: 3, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.blue,   row: 6, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green,  row: 0, col: 2, direction: MoveDir.down),
      Train(color: TrainColor.yellow, row: 0, col: 5, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 600),
    );
  }

  static LevelDef _level5() {
    // Full complexity: 4 trains, 5 junctions, faster
    // Use same 4-train layout as level 4 but add an extra junction in the middle
    // and speed up the game
    const r = 9;
    const c = 8;

    final grid = List.generate(r, (row) => List.generate(c, (col) {
      // Junctions (5 total)
      if (row == 2 && col == 2) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      if (row == 2 && col == 5) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1);
      if (row == 5 && col == 2) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      if (row == 5 && col == 5) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 1);
      if (row == 5 && col == 3) return TrackCell.junction(Port.left, Port.right, Port.top, Port.bottom, activeIdx: 0);
      // Stations
      if (row == 2 && col == 7) return TrackCell.station(TrainColor.red);
      if (row == 5 && col == 7) return TrackCell.station(TrainColor.blue);
      if (row == 8 && col == 2) return TrackCell.station(TrainColor.green);
      if (row == 8 && col == 5) return TrackCell.station(TrainColor.yellow);
      // Red track: row 2, cols 0..6
      if (row == 2 && col >= 0 && col <= 6) return TrackCell.straight(Port.left, Port.right);
      // Blue track: row 5, cols 0..6
      if (row == 5 && col >= 0 && col <= 6) return TrackCell.straight(Port.left, Port.right);
      // Green track: col 2, rows 0..7
      if (col == 2 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Yellow track: col 5, rows 0..7
      if (col == 5 && row >= 0 && row <= 7) return TrackCell.straight(Port.top, Port.bottom);
      // Extra vertical col 3, rows 0..4 leading into junction at (5,3)
      if (col == 3 && row >= 0 && row <= 4) return TrackCell.straight(Port.top, Port.bottom);
      return TrackCell.empty();
    }));

    final trains = [
      Train(color: TrainColor.red,    row: 2, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.blue,   row: 5, col: 0, direction: MoveDir.right),
      Train(color: TrainColor.green,  row: 0, col: 2, direction: MoveDir.down),
      Train(color: TrainColor.yellow, row: 0, col: 5, direction: MoveDir.down),
    ];

    return LevelDef(
      rows: r, cols: c, grid: grid, trains: trains,
      tickInterval: const Duration(milliseconds: 520),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Direction helpers
// ─────────────────────────────────────────────────────────────────────────────

extension MoveDirExt on MoveDir {
  Port get entryPort {
    switch (this) {
      case MoveDir.right: return Port.left;   // train moving right enters from left port
      case MoveDir.left:  return Port.right;
      case MoveDir.down:  return Port.top;
      case MoveDir.up:    return Port.bottom;
    }
  }

  MoveDir get opposite {
    switch (this) {
      case MoveDir.right: return MoveDir.left;
      case MoveDir.left:  return MoveDir.right;
      case MoveDir.down:  return MoveDir.up;
      case MoveDir.up:    return MoveDir.down;
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
