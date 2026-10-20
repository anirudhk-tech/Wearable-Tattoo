import processing.serial.*;

<<<<<<< HEAD
String PORT_NAME = "/dev/ttyACM0";
=======
String PACMAN_PORT_NAME = "/dev/cu.usbmodem123456781";
String GHOST_PORT_NAME = "/dev/cu.usbmodemXXXXXXXX";
>>>>>>> 0bd731c (pulling)
int baudrate = 115200;
Serial pacmanPort;
Serial ghostPort;

void setupSerial() {
    printArray(Serial.list());
    pacmanPort = new Serial(this, PACMAN_PORT_NAME, baudrate);
    pacmanPort.bufferUntil('\n');
    ghostPort = new Serial(this, GHOST_PORT_NAME, baudrate);
    ghostPort.bufferUntil('\n');
}

void serialEvent(Serial p) {
    String line = p.readStringUntil('\n');
    if (line == null) return;
    line = trim(line);
    println("serial: '" + line + "'");

    if (match(line, "^\\d+$") == null) return;

    int sensor = int(line);

    if (sensor == 8 || sensor == 9) {
        resetGame();
        return;
    }

    float dx = 0;
    float dy = 0;
    if (sensor == 0) dy = -10;
    if (sensor == 1) dy = 10;
    if (sensor == 2) dx = -10;
    if (sensor == 3) dx = 10;

    if (p == pacmanPort) pacman.move(dx, dy);
    if (p == ghostPort) ghost.move(dx, dy);
}
