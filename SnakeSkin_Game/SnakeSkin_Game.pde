/*
  SNAKE//SKIN  -  1v1 Snake on two Smart Tattoos
  Wearable Technology Lab (BME/CS 479) - Lab 3

  Requires: Processing 4 (Java mode). The Serial library ships with Processing.
  Hardware: two FireBeetle + MPR121 devices running SnakeSkin_Controller.ino
            (Device A = 'A' -> Player 1, Device B = 'B' -> Player 2)
  No hardware? Play with the keyboard fallback (see README).

  RULES
  - Screen edges wrap around.
  - Eat food: normal = +1 segment, golden = +3.
  - Bite the OTHER snake's body: it loses everything behind the bite point,
    and you GROW by that many segments (+5 pts each).
  - Head-on: the longer snake wins and the shorter one is eliminated
    (equal length -> both lose 3 segments).
  - Bite yourself: you lose your tail from that point (no growth).
  - A snake shorter than 3 segments is eliminated.
  - Match lasts 90 s: longest snake wins (ties -> higher score).
  - BOOST burns energy, which refills when you release it.

  PAD MAP (MPR121 electrodes 0-9)
            DEVICE A (P1)                 DEVICE B (P2)
   0-3      UP / DOWN / LEFT / RIGHT      UP / DOWN / LEFT / RIGHT
   4        BOOST (menu: select)          BOOST (menu: select)
   5        PAUSE / RESUME                PAUSE / RESUME
   6        RESTART match                 RESTART match
   7        MAIN MENU                     MAIN MENU
   8        SELECT / START                CYCLE THEME
   9        HIGH SCORES                   TOGGLE PAD DEBUG
*/

import processing.serial.*;

// ---------------------------------------------------------------- config
final int COLS = 40, ROWS = 26, CELL = 24;
final int BX = 30, BY = 120;
final int BW = COLS * CELL, BH = ROWS * CELL;
final int MATCH_SECONDS = 90;
final float BASE_STEP = 0.115;          // seconds per move
final int BAUD = 115200;

final int ST_MENU = 0, ST_PLAY = 1, ST_PAUSE = 2, ST_OVER = 3, ST_SCORES = 4;
int state = ST_MENU;
int menuSel = 0;
float menuAnim = 0;
String[] MENU = { "1v1  VERSUS", "SOLO  SCORE ATTACK", "HIGH  SCORES" };
String[] MENU_SUB = { "Eat. Bite. Outgrow your rival.", "Beat the clock, set a record.", "Hall of fame" };

String[] LBL_A = { "UP", "DN", "LT", "RT", "BST", "PSE", "RST", "MNU", "GO", "HI" };
String[] LBL_B = { "UP", "DN", "LT", "RT", "BST", "PSE", "RST", "MNU", "THM", "DBG" };

// themes: P1 head, P1 tail, P2 head, P2 tail
int[][] PAL = {
  { 0xFF00E5FF, 0xFF2979FF, 0xFFFF2D95, 0xFFFF8A00 },   // NEON
  { 0xFF69F0AE, 0xFF00B8D4, 0xFFB388FF, 0xFFFF4081 },   // AURORA
  { 0xFFFFD740, 0xFFFF6E40, 0xFF40C4FF, 0xFF536DFE }    // SUNSET
};
String[] THEME_NAME = { "NEON", "AURORA", "SUNSET" };
int theme = 0;

// ---------------------------------------------------------------- serial / input
ArrayList<Serial> links = new ArrayList<Serial>();
ArrayList<String> linkNames = new ArrayList<String>();
int[] devMask = new int[2];
int[] keyMask = new int[2];
int[] cur = new int[2];
int[] prevCur = new int[2];
int[] pressed = new int[2];
long[] lastSeen = { -99999, -99999 };
boolean dbg = false;

// ---- force strip (FS-L-0055-253-ST on Device A) ----
// Tune these with the live numbers shown on the main menu.
final int FSLP_POS_MIN = 150;       // position reading at the left end of the strip
final int FSLP_POS_MAX = 3900;      // position reading at the right end
final int FSLP_PRESS   = 700;       // force counts that count as a "firm press"
final boolean FSLP_FLIP = false;    // true if the strip is mounted the other way round
int fslpPos = -1, fslpForce = 0;
long fslpSeen = -99999;
boolean fslpFirmPrev = false;

// ---------------------------------------------------------------- game state
Snake p1, p2;
ArrayList<int[]> foods = new ArrayList<int[]>();   // {x, y, type}
ArrayList<Particle> particles = new ArrayList<Particle>();
boolean versus = true;
float timeLeft = MATCH_SECONDS;
long countdownEnd = 0;
long lastMs = 0;
float shake = 0;
String toast = "";
float toastT = 0;
int toastCol = 0xFFFFFFFF;
String resultTitle = "", resultSub = "";
int resultWinner = -1;

ArrayList<String[]> hs = new ArrayList<String[]>();   // {score, label, date}

PFont fBold, fReg, fMono;
PGraphics boardBG;

// ================================================================ setup
void setup() {
  size(1280, 780);
  smooth(4);
  surface.setTitle("SNAKE//SKIN");
  fBold = createFont("SansSerif.bold", 64, true);
  fReg  = createFont("SansSerif", 32, true);
  fMono = createFont("Monospaced.bold", 16, true);
  buildBoardBG();
  loadScores();
  connectSerial();
  lastMs = millis();
}

void buildBoardBG() {
  boardBG = createGraphics(BW, BH);
  boardBG.beginDraw();
  boardBG.background(7, 9, 20);
  boardBG.noStroke();
  for (int x = 0; x < COLS; x++) {
    for (int y = 0; y < ROWS; y++) {
      boardBG.fill(255, ((x + y) % 2 == 0) ? 7 : 3);
      boardBG.rect(x * CELL, y * CELL, CELL, CELL);
      boardBG.fill(255, 38);
      boardBG.ellipse(x * CELL + CELL / 2, y * CELL + CELL / 2, 2.2, 2.2);
    }
  }
  boardBG.endDraw();
}

void connectSerial() {
  for (Serial s : links) s.stop();
  links.clear();
  linkNames.clear();
  String[] list = Serial.list();
  for (String name : list) {
    String low = name.toLowerCase();
    if (low.contains("bluetooth") || low.contains("debug-console")) continue;
    if (!(low.contains("usb") || low.contains("acm") || low.contains("com") || low.contains("wch"))) continue;
    try {
      Serial s = new Serial(this, name, BAUD);
      links.add(s);
      linkNames.add(name);
      println("Opened " + name);
    } catch (Exception e) {
      println("Could not open " + name);
    }
  }
  println("Serial links: " + links.size() + "  (press C to rescan)");
}

// ================================================================ main loop
void draw() {
  pollSerial();
  computeInput();
  handleMeta();
  handleStrip();
  update();

  drawBackground();
  if (state == ST_MENU) drawMenu();
  else if (state == ST_SCORES) drawScores();
  else drawGameScene();
}

void pollSerial() {
  for (Serial s : links) {
    while (s.available() > 0) {
      String line = s.readStringUntil('\n');
      if (line == null) break;
      String[] p = split(trim(line), ',');
      if (p.length == 4 && p[0].equals("F") && p[1].equals("A")) {
        fslpPos = int(p[2]);
        fslpForce = int(p[3]);
        fslpSeen = millis();
      }
      if (p.length == 3 && p[0].equals("T")) {
        int idx = p[1].equals("A") ? 0 : (p[1].equals("B") ? 1 : -1);
        if (idx >= 0) {
          devMask[idx] = int(p[2]) & 0x3FF;
          lastSeen[idx] = millis();
        }
      }
    }
  }
  for (int i = 0; i < 2; i++) if (millis() - lastSeen[i] > 600) devMask[i] = 0;
}

boolean linked(int i) { return millis() - lastSeen[i] < 600; }

void computeInput() {
  for (int p = 0; p < 2; p++) {
    cur[p] = devMask[p] | keyMask[p];
    pressed[p] = cur[p] & ~prevCur[p];
    prevCur[p] = cur[p];
  }
}

boolean has(int m, int bit) { return (m & (1 << bit)) != 0; }

boolean stripLive() { return millis() - fslpSeen < 600; }

// 0..1 position along the strip (respects FSLP_FLIP)
float stripNorm() {
  float n = constrain((fslpPos - FSLP_POS_MIN) / float(FSLP_POS_MAX - FSLP_POS_MIN), 0, 1);
  return FSLP_FLIP ? 1 - n : n;
}

// Main menu: slide to highlight, press firmly to select
void handleStrip() {
  if (!stripLive()) { fslpFirmPrev = false; return; }
  boolean touched = fslpPos >= 0;
  boolean firm = touched && fslpForce >= FSLP_PRESS;
  if (state == ST_MENU && touched) {
    float f = stripNorm() * MENU.length;
    // hysteresis so the highlight doesn't flicker on zone borders
    if (f < menuSel - 0.12 || f > menuSel + 1.12) menuSel = constrain(floor(f), 0, MENU.length - 1);
  }
  if (firm && !fslpFirmPrev && state == ST_MENU) actSelect();
  fslpFirmPrev = firm;
}

void handleMeta() {
  for (int p = 0; p < 2; p++) {
    int pr = pressed[p];
    if (pr == 0) continue;
    if (state == ST_MENU) {
      if (has(pr, 0)) menuSel = (menuSel + MENU.length - 1) % MENU.length;
      if (has(pr, 1)) menuSel = (menuSel + 1) % MENU.length;
      if (has(pr, 4)) actSelect();
    }
    if (has(pr, 5)) actPause();
    if (has(pr, 6)) actRestart();
    if (has(pr, 7)) actMenu();
    if (p == 0 && has(pr, 8)) actSelect();
    if (p == 0 && has(pr, 9)) actScores();
    if (p == 1 && has(pr, 8)) actTheme();
    if (p == 1 && has(pr, 9)) actDebug();
  }
}

void actPause() {
  if (state == ST_PLAY && millis() >= countdownEnd) state = ST_PAUSE;
  else if (state == ST_PAUSE) state = ST_PLAY;
}
void actRestart() { if (state == ST_PLAY || state == ST_PAUSE || state == ST_OVER) startGame(versus); }
void actMenu() { state = ST_MENU; }
void actScores() { state = ST_SCORES; }
void actTheme() { theme = (theme + 1) % PAL.length; }
void actDebug() { dbg = !dbg; }
void actSelect() {
  if (state == ST_MENU) {
    if (menuSel == 0) startGame(true);
    else if (menuSel == 1) startGame(false);
    else state = ST_SCORES;
  } else if (state == ST_OVER) startGame(versus);
  else if (state == ST_PAUSE) state = ST_PLAY;
  else if (state == ST_SCORES) state = ST_MENU;
}

// ---------------------------------------------------------------- keyboard fallback
void keyPressed() { mapKey(true); }
void keyReleased() { mapKey(false); }

void mapKey(boolean down) {
  if (key == CODED) {
    if (keyCode == UP) setKey(1, 0, down);
    else if (keyCode == DOWN) setKey(1, 1, down);
    else if (keyCode == LEFT) setKey(1, 2, down);
    else if (keyCode == RIGHT) setKey(1, 3, down);
    return;
  }
  char k = Character.toLowerCase(key);
  if (k == 'w') setKey(0, 0, down);
  else if (k == 's') setKey(0, 1, down);
  else if (k == 'a') setKey(0, 2, down);
  else if (k == 'd') setKey(0, 3, down);
  else if (k == 'e') setKey(0, 4, down);
  else if (k == '.') setKey(1, 4, down);
  if (!down) return;
  if (key == ENTER || key == RETURN) actSelect();
  else if (k == 'p') actPause();
  else if (k == 'r') actRestart();
  else if (k == 'm') actMenu();
  else if (k == 'h') actScores();
  else if (k == 't') actTheme();
  else if (k == 'g') actDebug();
  else if (k == 'c') connectSerial();
}

void setKey(int p, int bit, boolean on) {
  if (on) keyMask[p] |= (1 << bit);
  else keyMask[p] &= ~(1 << bit);
}

// ================================================================ game logic
class Snake {
  int id, dx, dy, ndx, ndy, grow = 0, score = 0, foodsEaten = 0, bites = 0;
  float energy = 100, acc = 0;
  boolean alive = true, boosting = false;
  ArrayList<int[]> b = new ArrayList<int[]>();

  Snake(int id, int sx, int sy, int dirx, int diry) {
    this.id = id;
    dx = ndx = dirx;
    dy = ndy = diry;
    for (int i = 0; i < 5; i++) b.add(new int[] { (sx - dirx * i + COLS) % COLS, (sy - diry * i + ROWS) % ROWS });
  }
  int len() { return b.size(); }
}

class Particle {
  float x, y, vx, vy, life, max, sz;
  int col;
  Particle(float x, float y, int col) {
    this.x = x; this.y = y; this.col = col;
    float a = random(TWO_PI), s = random(40, 220);
    vx = cos(a) * s; vy = sin(a) * s;
    max = life = random(0.35, 0.9);
    sz = random(3, 8);
  }
  void update(float dt) { x += vx * dt; y += vy * dt; vx *= 0.95; vy *= 0.95; life -= dt; }
  void show() {
    float k = max(life / max, 0);
    noStroke();
    fill(col, 255 * k);
    ellipse(x, y, sz * k + 1, sz * k + 1);
  }
}

void startGame(boolean vs) {
  versus = vs;
  p1 = new Snake(0, 6, ROWS / 2, 1, 0);
  p2 = vs ? new Snake(1, COLS - 7, ROWS / 2, -1, 0) : null;
  foods.clear();
  particles.clear();
  for (int i = 0; i < (vs ? 5 : 4); i++) spawnFood();
  timeLeft = MATCH_SECONDS;
  countdownEnd = millis() + 3200;
  toast = "";
  state = ST_PLAY;
}

int segIndex(Snake s, int x, int y) {
  for (int i = 0; i < s.b.size(); i++) {
    int[] c = s.b.get(i);
    if (c[0] == x && c[1] == y) return i;
  }
  return -1;
}

boolean occupied(int x, int y) {
  if (p1 != null && segIndex(p1, x, y) >= 0) return true;
  if (p2 != null && segIndex(p2, x, y) >= 0) return true;
  for (int[] f : foods) if (f[0] == x && f[1] == y) return true;
  return false;
}

void spawnFood() {
  for (int tries = 0; tries < 200; tries++) {
    int x = int(random(COLS)), y = int(random(ROWS));
    if (!occupied(x, y)) {
      foods.add(new int[] { x, y, random(1) < 0.12 ? 1 : 0 });
      return;
    }
  }
}

void burst(int cx, int cy, int col, int n) {
  for (int i = 0; i < n; i++) particles.add(new Particle(BX + cx * CELL + CELL / 2, BY + cy * CELL + CELL / 2, col));
}

void say(String t, int col) { toast = t; toastT = 1.4; toastCol = col; }

void cutTo(Snake s, int n) {
  for (int i = n; i < s.b.size(); i++) {
    if (i % 2 == 0) { int[] c = s.b.get(i); burst(c[0], c[1], PAL[theme][s.id * 2 + 1], 3); }
  }
  while (s.b.size() > n) s.b.remove(s.b.size() - 1);
}

void kill(Snake s) {
  s.alive = false;
  for (int[] c : s.b) burst(c[0], c[1], PAL[theme][s.id * 2], 2);
  shake = 14;
}

void steer(Snake s, int m, int pm) {
  int bits = (pm & 15) != 0 ? pm : m;
  if (has(bits, 0) && s.dy != 1) { s.ndx = 0; s.ndy = -1; }
  else if (has(bits, 1) && s.dy != -1) { s.ndx = 0; s.ndy = 1; }
  else if (has(bits, 2) && s.dx != 1) { s.ndx = -1; s.ndy = 0; }
  else if (has(bits, 3) && s.dx != -1) { s.ndx = 1; s.ndy = 0; }
}

void stepSnake(Snake me, Snake other) {
  me.dx = me.ndx; me.dy = me.ndy;
  int[] h = me.b.get(0);
  int nx = (h[0] + me.dx + COLS) % COLS, ny = (h[1] + me.dy + ROWS) % ROWS;

  if (other != null && other.alive) {
    int i = segIndex(other, nx, ny);
    if (i == 0) {                                   // head-on
      if (me.len() > other.len()) { say("HEAD-ON! P" + (me.id + 1) + " CRUSHES P" + (other.id + 1), PAL[theme][me.id * 2]); kill(other); }
      else if (me.len() < other.len()) { say("HEAD-ON! P" + (other.id + 1) + " CRUSHES P" + (me.id + 1), PAL[theme][other.id * 2]); kill(me); return; }
      else {
        cutTo(me, max(me.len() - 3, 0)); cutTo(other, max(other.len() - 3, 0));
        say("CLASH! both lose 3", 0xFFFFFFFF); shake = 10;
        if (me.len() < 3) kill(me);
        if (other.len() < 3) kill(other);
        return;
      }
    } else if (i > 0) {                             // bite!
      int removed = other.len() - i;
      cutTo(other, i);
      me.grow += removed; me.bites++; me.score += removed * 5;
      burst(nx, ny, PAL[theme][me.id * 2], 18);
      say("P" + (me.id + 1) + " BITES P" + (other.id + 1) + "  +" + removed, PAL[theme][me.id * 2]);
      shake = 8;
      if (other.len() < 3) kill(other);
    }
  }

  int j = segIndex(me, nx, ny);                     // self bite
  if (j > 0 && !(j == me.len() - 1 && me.grow == 0)) {
    cutTo(me, j);
    say("P" + (me.id + 1) + " BIT ITSELF", 0xFFFF5252);
    shake = 6;
    if (me.len() < 3) { kill(me); return; }
  }

  me.b.add(0, new int[] { nx, ny });
  if (me.grow > 0) me.grow--;
  else me.b.remove(me.b.size() - 1);

  for (int k = 0; k < foods.size(); k++) {          // food
    int[] f = foods.get(k);
    if (f[0] == nx && f[1] == ny) {
      boolean gold = f[2] == 1;
      me.grow += gold ? 3 : 1;
      me.score += gold ? 30 : 10;
      me.foodsEaten++;
      burst(nx, ny, gold ? 0xFFFFD54F : 0xFF69F0AE, gold ? 22 : 12);
      foods.remove(k);
      spawnFood();
      break;
    }
  }
}

void update() {
  float dt = min((millis() - lastMs) / 1000.0, 0.05);
  lastMs = millis();

  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update(dt);
    if (p.life <= 0) particles.remove(i);
  }
  shake *= 0.9;
  if (toastT > 0) toastT -= dt;

  if (state != ST_PLAY || millis() < countdownEnd) return;

  timeLeft -= dt;
  if (timeLeft <= 0) { timeLeft = 0; endGame(); return; }

  Snake[] all = versus ? new Snake[] { p1, p2 } : new Snake[] { p1 };
  for (Snake s : all) {
    if (!s.alive) continue;
    steer(s, cur[s.id], pressed[s.id]);
    s.boosting = has(cur[s.id], 4) && s.energy > 2;
    if (s.boosting) s.energy = max(0, s.energy - 38 * dt);
    else s.energy = min(100, s.energy + 14 * dt);
    s.acc += dt;
    float step = BASE_STEP * (s.boosting ? 0.5 : 1.0);
    if (s.acc >= step) {
      s.acc -= step;
      stepSnake(s, s == p1 ? p2 : p1);
    }
  }
  if (!p1.alive || (versus && !p2.alive)) endGame();
}

void endGame() {
  if (state == ST_OVER) return;
  state = ST_OVER;
  int w = -1;
  if (versus) {
    if (!p1.alive && !p2.alive) { w = -1; resultSub = "Mutual destruction"; }
    else if (!p1.alive) { w = 1; resultSub = "Player 1 was eliminated"; }
    else if (!p2.alive) { w = 0; resultSub = "Player 2 was eliminated"; }
    else if (p1.len() != p2.len()) { w = p1.len() > p2.len() ? 0 : 1; resultSub = "Time's up - longest snake wins"; }
    else if (p1.score != p2.score) { w = p1.score > p2.score ? 0 : 1; resultSub = "Tied on length - score decides"; }
    else resultSub = "A perfect tie";
    resultTitle = w < 0 ? "DRAW" : "PLAYER " + (w + 1) + " WINS";
    addScore("VS  P1", p1.score + (w == 0 ? 50 : 0));
    addScore("VS  P2", p2.score + (w == 1 ? 50 : 0));
  } else {
    resultTitle = p1.alive ? "TIME!" : "WIPED OUT";
    resultSub = "Final length " + p1.len();
    addScore("SOLO", p1.score);
  }
  resultWinner = w;
}

// ---------------------------------------------------------------- high scores
void loadScores() {
  hs.clear();
  File f = new File(sketchPath("highscores.txt"));
  if (!f.exists()) return;
  String[] lines = loadStrings(f.getAbsolutePath());
  if (lines == null) return;
  for (String l : lines) {
    String[] p = split(l, ',');
    if (p.length == 3) hs.add(p);
  }
}

void addScore(String label, int score) {
  hs.add(new String[] { str(score), label, nf(month(), 2) + "/" + nf(day(), 2) });
  java.util.Collections.sort(hs, new java.util.Comparator<String[]>() {
    public int compare(String[] a, String[] b) { return int(b[0]) - int(a[0]); }
  });
  while (hs.size() > 8) hs.remove(hs.size() - 1);
  String[] out = new String[hs.size()];
  for (int i = 0; i < out.length; i++) out[i] = join(hs.get(i), ",");
  saveStrings(sketchPath("highscores.txt"), out);
}

// ================================================================ drawing helpers
void drawBackground() {
  noStroke();
  for (int y = 0; y < height; y += 4) {
    fill(lerpColor(color(7, 9, 20), color(18, 11, 36), y / (float) height));
    rect(0, y, width, 4);
  }
  float t = millis() / 1000.0;
  for (int i = 0; i < 3; i++) {
    float ox = width * (0.2 + 0.3 * i) + sin(t * 0.3 + i * 2) * 120;
    float oy = height * (0.3 + 0.2 * i) + cos(t * 0.25 + i) * 90;
    int c = PAL[theme][(i % 2) * 2];
    for (int g = 6; g >= 1; g--) { fill(c, 5); ellipse(ox, oy, g * 120, g * 120); }
  }
}

void glass(float x, float y, float w, float h, float r, int a) {
  noStroke(); fill(255, a); rect(x, y, w, h, r);
  stroke(255, 30); strokeWeight(1); noFill(); rect(x, y, w, h, r);
  noStroke();
}

void gradientText(String s, float x, float y, float size, int c1, int c2) {
  textFont(fBold); textSize(size); textAlign(LEFT, CENTER);
  float cx = x;
  for (int i = 0; i < s.length(); i++) {
    fill(lerpColor(c1, c2, s.length() > 1 ? i / (float) (s.length() - 1) : 0));
    text(s.charAt(i), cx, y);
    cx += textWidth(s.charAt(i));
  }
}

void label(String s, float x, float y, float size, int col, int al) {
  textFont(fReg); textSize(size); textAlign(al, CENTER); fill(col); text(s, x, y);
}
void bold(String s, float x, float y, float size, int col, int al) {
  textFont(fBold); textSize(size); textAlign(al, CENTER); fill(col); text(s, x, y);
}

void bar(float x, float y, float w, float h, float k, int col) {
  noStroke(); fill(255, 22); rect(x, y, w, h, h);
  fill(col); rect(x, y, max(h, w * constrain(k, 0, 1)), h, h);
}

// ================================================================ menu
void drawMenu() {
  float t = millis() / 1000.0;
  int c1 = PAL[theme][0], c2 = PAL[theme][2];
  gradientText("SNAKE", 110, 150, 112, color(255), color(255));
  gradientText("//SKIN", 110, 250, 112, c1, c2);
  label("SMART TATTOO ARENA   |   1v1 CAPACITIVE SNAKE", 114, 318, 18, color(255, 150), LEFT);

  menuAnim = lerp(menuAnim, menuSel, 0.25);
  for (int i = 0; i < MENU.length; i++) {
    float y = 380 + i * 92;
    boolean sel = (i == menuSel);
    float w = 560 + (sel ? 24 : 0);
    glass(110, y, w, 76, 20, sel ? 26 : 10);
    if (sel) {
      noFill(); stroke(c1, 200); strokeWeight(2); rect(110, y, w, 76, 20);
      stroke(c1, 40); strokeWeight(6); rect(110, y, w, 76, 20); noStroke();
      fill(c1); rect(124, y + 22, 5, 32, 3);
    }
    bold(MENU[i], 150, y + 29, 28, sel ? color(255) : color(255, 160), LEFT);
    label(MENU_SUB[i], 150, y + 57, 15, color(255, sel ? 160 : 90), LEFT);
  }

  // link status chips
  chip(850, 150, "DEVICE A  ·  PLAYER 1", linked(0), PAL[theme][0]);
  chip(850, 200, "DEVICE B  ·  PLAYER 2", linked(1), PAL[theme][2]);
  label("keyboard fallback active", 850, 258, 14, color(255, 100), LEFT);

  // pad cheat sheet
  glass(850, 300, 390, 360, 22, 10);
  bold("TATTOO PAD MAP", 874, 330, 18, color(255, 220), LEFT);
  String[][] rows = {
    { "0 1 2 3", "UP  DOWN  LEFT  RIGHT" }, { "4", "BOOST  /  select in menu" },
    { "5", "PAUSE" }, { "6", "RESTART" }, { "7", "MAIN MENU" },
    { "A · 8", "SELECT / START" }, { "A · 9", "HIGH SCORES" },
    { "B · 8", "CYCLE THEME" }, { "B · 9", "PAD DEBUG" }
  };
  for (int i = 0; i < rows.length; i++) {
    float y = 372 + i * 32;
    bold(rows[i][0], 874, y, 15, c1, LEFT);
    label(rows[i][1], 960, y, 15, color(255, 190), LEFT);
  }
  drawStrip(110, 656, 560);
  label("Don't touch pads while powering up (calibration).", 850, 690, 13, color(255, 90), LEFT);
  label("Keys:  WASD+E  /  arrows+.  ·  Enter  P  R  M  H  T  G  C", 850, 712, 13, color(255, 90), LEFT);
}

void drawStrip(float x, float y, float w) {
  int c1 = PAL[theme][0];
  boolean live = stripLive();
  boolean touched = live && fslpPos >= 0;
  boolean firm = touched && fslpForce >= FSLP_PRESS;
  glass(x, y, w, 76, 18, 10);
  label("FORCE STRIP", x + 20, y + 15, 12, color(255, 120), LEFT);
  label(live ? "slide = choose   ·   press firmly = select" : "not detected (needs Device A with HAS_FSLP 1)",
        x + w - 20, y + 15, 12, color(255, 110), RIGHT);

  float tx = x + 20, tw = w - 40, ty = y + 30, th = 24;
  String[] zn = { "VERSUS", "SOLO", "SCORES" };
  noStroke();
  for (int i = 0; i < MENU.length; i++) {
    float zw = tw / MENU.length, zx = tx + i * zw;
    boolean sel = (i == menuSel);
    fill(sel ? c1 : color(255), sel ? 55 : 14);
    rect(zx + 2, ty, zw - 4, th, 9);
    label(zn[i], zx + zw / 2, ty + th / 2, 12, sel ? color(255) : color(255, 110), CENTER);
  }
  if (touched) {
    float mx = tx + stripNorm() * tw;
    float k = constrain(fslpForce / float(FSLP_PRESS), 0, 1.3);
    float r = 7 + 9 * k;
    fill(firm ? color(255) : c1, 50); ellipse(mx, ty + th / 2, r * 2 + 12, r * 2 + 12);
    fill(firm ? color(255) : c1); ellipse(mx, ty + th / 2, r, r);
  }
  label("pos " + (touched ? str(fslpPos) : "--") + "   force " + (live ? str(fslpForce) : "--")
        + "   (press at " + FSLP_PRESS + ")", x + 20, y + 66, 11, color(255, 90), LEFT);
}

void chip(float x, float y, String s, boolean on, int col) {
  glass(x, y, 390, 38, 19, 12);
  if (on) {
    fill(0xFF69F0AE, 50); ellipse(x + 22, y + 19, 20, 20);
    fill(0xFF69F0AE); ellipse(x + 22, y + 19, 10, 10);
  }
  label(s, x + 42, y + 19, 15, color(255, 210), LEFT);
  label(on ? "LINKED" : "OFFLINE", x + 372, y + 19, 13, on ? color(0xFF69F0AE) : color(255, 110), RIGHT);
}

// ================================================================ scores
void drawScores() {
  int c1 = PAL[theme][0];
  gradientText("HIGH SCORES", 110, 120, 70, c1, PAL[theme][2]);
  glass(110, 190, 760, 520, 24, 10);
  if (hs.size() == 0) label("No scores yet - go play!", 490, 450, 22, color(255, 140), CENTER);
  for (int i = 0; i < hs.size(); i++) {
    float y = 232 + i * 60;
    if (i == 0) { fill(c1, 25); rect(126, y - 26, 728, 52, 14); }
    bold("#" + (i + 1), 160, y, 24, i == 0 ? c1 : color(255, 140), LEFT);
    bold(hs.get(i)[0], 270, y, 28, color(255), LEFT);
    label(hs.get(i)[1], 480, y, 20, color(255, 170), LEFT);
    label(hs.get(i)[2], 820, y, 18, color(255, 100), RIGHT);
  }
  label("Pad 7 / 8 (or Enter)  to go back", 110, 745, 16, color(255, 110), LEFT);
}

// ================================================================ game scene
void drawGameScene() {
  pushMatrix();
  if (shake > 0.3) translate(random(-shake, shake), random(-shake, shake));
  drawHUD();
  drawBoard();
  popMatrix();
  drawSidePanel();

  if (state == ST_PLAY && millis() < countdownEnd) {
    int n = ceil((countdownEnd - millis()) / 1000.0 - 0.2);
    fill(0, 120); rect(BX, BY, BW, BH, 14);
    float k = ((countdownEnd - millis()) % 1000) / 1000.0;
    bold(n > 0 ? str(n) : "GO!", BX + BW / 2, BY + BH / 2 - 10, 140 + 60 * k, color(255, 120 + 135 * k), CENTER);
    label(versus ? "P1 ◀ ▶  P2" : "SOLO", BX + BW / 2, BY + BH / 2 + 90, 24, color(255, 140), CENTER);
  }
  if (state == ST_PAUSE) {
    fill(0, 160); rect(BX, BY, BW, BH, 14);
    bold("PAUSED", BX + BW / 2, BY + BH / 2 - 20, 80, color(255), CENTER);
    label("pad 5 to resume   ·   pad 7 for menu", BX + BW / 2, BY + BH / 2 + 50, 20, color(255, 150), CENTER);
  }
  if (state == ST_OVER) drawOver();
}

void drawBoard() {
  glass(BX - 10, BY - 10, BW + 20, BH + 20, 22, 8);
  image(boardBG, BX, BY);
  noFill(); stroke(255, 20); strokeWeight(1); rect(BX, BY, BW, BH, 4); noStroke();

  for (int[] f : foods) {
    float cx = BX + f[0] * CELL + CELL / 2, cy = BY + f[1] * CELL + CELL / 2;
    boolean gold = f[2] == 1;
    int col = gold ? 0xFFFFD54F : 0xFF69F0AE;
    float r = (gold ? 8.5 : 6.5) + 1.8 * sin(frameCount * 0.12 + f[0] * 0.7);
    for (int g = 4; g >= 1; g--) { fill(col, 20); ellipse(cx, cy, r * 2 + g * 7, r * 2 + g * 7); }
    fill(col); ellipse(cx, cy, r * 2, r * 2);
    fill(255, 160); ellipse(cx - r * 0.3, cy - r * 0.3, r * 0.7, r * 0.7);
  }

  if (p1 != null) drawSnake(p1);
  if (p2 != null) drawSnake(p2);
  for (Particle p : particles) p.show();

  if (toastT > 0) {
    float a = constrain(toastT * 2, 0, 1);
    textFont(fBold); textSize(22);
    float w = textWidth(toast) + 50;
    fill(0, 150 * a); rect(BX + BW / 2 - w / 2, BY + 12, w, 40, 20);
    fill(toastCol, 255 * a); textAlign(CENTER, CENTER); text(toast, BX + BW / 2, BY + 31);
  }
}

void drawSnake(Snake s) {
  int c1 = PAL[theme][s.id * 2], c2 = PAL[theme][s.id * 2 + 1];
  int n = s.len();
  noStroke();
  for (int i = n - 1; i >= 0; i--) {
    int[] c = s.b.get(i);
    float t = n > 1 ? i / (float) (n - 1) : 0;
    float x = BX + c[0] * CELL, y = BY + c[1] * CELL;
    if (i == 0) {
      for (int g = 3; g >= 1; g--) { fill(c1, s.boosting ? 34 : 20); rect(x - g * 4, y - g * 4, CELL + g * 8, CELL + g * 8, 10 + g * 3); }
    }
    float inset = (i == 0) ? 0.5 : 2.5;
    fill(s.alive ? lerpColor(c1, c2, t) : color(90), 240);
    rect(x + inset, y + inset, CELL - inset * 2, CELL - inset * 2, 8);
    if (i > 0) { fill(255, 28 * (1 - t)); rect(x + 5, y + 4, CELL - 10, 5, 3); }
  }
  int[] h = s.b.get(0);
  float cx = BX + h[0] * CELL + CELL / 2, cy = BY + h[1] * CELL + CELL / 2;
  for (int sd = -1; sd <= 1; sd += 2) {
    float ex = cx + s.dx * 4 - s.dy * 5 * sd, ey = cy + s.dy * 4 + s.dx * 5 * sd;
    fill(255); ellipse(ex, ey, 9, 9);
    fill(10); ellipse(ex + s.dx * 1.5, ey + s.dy * 1.5, 4, 4);
  }
}

void drawHUD() {
  playerCard(p1, 0, BX, 18);
  if (versus) playerCard(p2, 1, BX + BW - 300, 18);
  else {
    glass(BX + BW - 300, 18, 300, 84, 20, 6);
    label("SOLO MODE", BX + BW - 150, 60, 20, color(255, 90), CENTER);
  }
  float cx = BX + BW / 2;
  label(versus ? "1 v 1" : "SOLO", cx, 28, 15, color(255, 110), CENTER);
  int secs = ceil(timeLeft);
  int tc = timeLeft < 10 ? color(0xFFFF5252) : color(255);
  if (timeLeft < 10 && frameCount % 30 < 15) tc = color(255, 130, 130);
  bold(nf(secs / 60, 1) + ":" + nf(secs % 60, 2), cx, 66, 54, tc, CENTER);
  bar(cx - 80, 98, 160, 5, timeLeft / MATCH_SECONDS, tc);
}

void playerCard(Snake s, int id, float x, float y) {
  int c1 = PAL[theme][id * 2], c2 = PAL[theme][id * 2 + 1];
  glass(x, y, 300, 84, 20, 12);
  fill(c1); rect(x, y + 18, 4, 48, 2);
  label("PLAYER " + (id + 1) + (linked(id) ? "  ·  TATTOO" : "  ·  KEYS"), x + 20, y + 16, 12, color(255, 120), LEFT);
  bold(str(s.score), x + 20, y + 44, 38, color(255), LEFT);
  label("LEN " + s.len(), x + 160, y + 34, 15, c1, LEFT);
  label("BITES " + s.bites + "   FOOD " + s.foodsEaten, x + 160, y + 54, 13, color(255, 140), LEFT);
  bar(x + 20, y + 70, 260, 6, s.energy / 100.0, s.boosting ? color(255) : c2);
}

void drawSidePanel() {
  float x = 1010, y = 18, w = 240;
  glass(x, y, w, 726, 24, 8);
  bold("SKIN LINK", x + 20, y + 30, 20, color(255, 230), LEFT);
  label(THEME_NAME[theme], x + w - 20, y + 30, 13, PAL[theme][0], RIGHT);
  deviceBlock(0, "A", "P1", LBL_A, x + 10, y + 56);
  if (versus) deviceBlock(1, "B", "P2", LBL_B, x + 10, y + 264);
  label("pads: touch = press", x + 20, y + 480, 13, color(255, 90), LEFT);
  label("UP DN LT RT   steer", x + 20, y + 510, 13, color(255, 140), LEFT);
  label("BST   boost (uses energy)", x + 20, y + 532, 13, color(255, 140), LEFT);
  label("PSE   pause   RST   restart", x + 20, y + 554, 13, color(255, 140), LEFT);
  label("MNU   main menu", x + 20, y + 576, 13, color(255, 140), LEFT);
  label("A: GO select   HI scores", x + 20, y + 598, 13, color(255, 140), LEFT);
  label("B: THM theme   DBG numbers", x + 20, y + 620, 13, color(255, 140), LEFT);
  label("golden food = +3 length", x + 20, y + 660, 13, 0xFFFFD54F, LEFT);
  label("bite a body = steal its tail", x + 20, y + 682, 13, color(255, 140), LEFT);
  label("keys: C rescan serial", x + 20, y + 704, 13, color(255, 90), LEFT);
}

void deviceBlock(int id, String dev, String who, String[] lbl, float x, float y) {
  int col = PAL[theme][id * 2];
  boolean on = linked(id);
  glass(x, y, 220, 196, 18, 8);
  if (on) { fill(0xFF69F0AE); ellipse(x + 20, y + 24, 9, 9); }
  label("DEVICE " + dev + "  ·  " + who, x + 36, y + 24, 14, color(255, 220), LEFT);
  label(on ? "LINKED" : "no link", x + 208, y + 24, 12, color(255, 110), RIGHT);
  for (int i = 0; i < 10; i++) {
    float px = x + 8 + (i % 5) * 42, py = y + 50 + (i / 5) * 66;
    boolean t = has(cur[id], i);
    if (t) { for (int g = 3; g >= 1; g--) { fill(col, 30); rect(px - g * 2, py - g * 2, 38 + g * 4, 38 + g * 4, 10 + g * 2); } }
    noStroke(); fill(t ? col : color(255, 14)); rect(px, py, 38, 38, 10);
    textFont(fBold); textSize(11); textAlign(CENTER, CENTER);
    fill(t ? color(10) : color(255, 150)); text(lbl[i], px + 19, py + 19);
    if (dbg) { textFont(fMono); textSize(10); fill(t ? color(10) : color(255, 90)); text(i, px + 19, py + 48); }
  }
  if (dbg) { label("mask " + cur[id], x + 110, y + 184, 11, color(255, 110), CENTER); }
}

void drawOver() {
  fill(0, 170); rect(0, 0, width, height);
  glass(340, 190, 600, 400, 30, 14);
  int c = resultWinner >= 0 ? PAL[theme][resultWinner * 2] : color(255);
  label("MATCH OVER", 640, 240, 16, color(255, 120), CENTER);
  bold(resultTitle, 640, 310, 72, c, CENTER);
  label(resultSub, 640, 370, 20, color(255, 170), CENTER);
  if (versus) {
    stat(450, 450, "P1", p1, PAL[theme][0]);
    stat(830, 450, "P2", p2, PAL[theme][2]);
  } else stat(640, 450, "YOU", p1, PAL[theme][0]);
  label("pad 6 restart   ·   pad 7 menu   ·   pad 9 scores", 640, 555, 16, color(255, 120), CENTER);
}

void stat(float x, float y, String who, Snake s, int col) {
  bold(who, x, y - 30, 20, col, CENTER);
  bold(str(s.score), x, y + 8, 50, color(255), CENTER);
  label("len " + s.len() + "   bites " + s.bites + "   food " + s.foodsEaten, x, y + 52, 15, color(255, 140), CENTER);
}
