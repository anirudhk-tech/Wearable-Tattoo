import processing.serial.*;

String PORT_NAME = "/dev/cu.usbmodem123456781";
int baudrate = 115200;
Serial port;

void setupSerial() {
    printArray(Serial.list());
    port = new Serial(this, PORT_NAME, baudrate);
    port.bufferUntil('\n');
}

void serialEvent(Serial p) {
    String line = p.readStringUntil('\n');
    if (line == null) return;
    line = trim(line);
    println("serial: '" + line + "'");

    if (match(line, "^\\d+$") == null) return;

    int sensor = int(line);
    if (sensor == 0) pacman.move(0, -10);
    if (sensor == 1) pacman.move(0, 10);
    if (sensor == 2) pacman.move(-10, 0);
    if (sensor == 3) pacman.move(10, 0);

    if (sensor == 4) ghost.move(0, -10);
    if (sensor == 5) ghost.move(0, 10);
    if (sensor == 6) ghost.move(-10, 0);
    if (sensor == 7) ghost.move(10, 0);

    if (sensor == 8 || sensor == 9) resetGame();
}
