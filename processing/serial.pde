import processing.serial.*;

String PACMAN_PORT_NAME = "/dev/ttyACM0";
String GHOST_PORT_NAME = "/dev/ttyACM1";
int baudrate = 115200;
Serial pacmanPort;
Serial ghostPort;

void setupSerial() {
    printArray(Serial.list());
    pacmanPort = new Serial(this, PACMAN_PORT_NAME, baudrate);
    pacmanPort.bufferUntil('\n');
    //ghostPort = new Serial(this, GHOST_PORT_NAME, baudrate);
    //ghostPort.bufferUntil('\n');
}

void serialEvent(Serial p) {
    String line = p.readStringUntil('\n');
    if (line == null) return;
    line = trim(line);
    
    if (p == pacmanPort) {
      println("PACMAN serial: " + line);
    } else {
      println("GHOST serial: " + line);
    }

    if (match(line, "^\\d+$") == null) return;

    int sensor = int(line);
/*
    if (sensor == 8 || sensor == 9) {
        resetGame();
        return;
    }
*/
    float dx = 0;
    float dy = 0;
    if (sensor == 0) dy = -10;
    if (sensor == 1) dy = 10;
    if (sensor == 2) dx = -10;
    if (sensor == 3) dx = 10;

    if (p == pacmanPort){
      if( pacman.turbo > 1 && turbo ){
        dx *= 2;
        dy *= 2;
        pacman.changeTurbo(-2);
      }
      
      //println("Pacman x: " + dx + ", y: " + dy);
      pacman.move(dx, dy);
      checkPoints();
      checkGameOver();
      if (sensor == 4)  pacman.changeColor();
    }
    
    /*
    if (p == ghostPort){
      if( ghost.turbo > 1 && turbo ){
        dx *= 2;
        dy *= 2;
        ghost.changeTurbo(-2);
      }
      
      ghost.move(dx, dy);
      checkGameOver();
      if (sensor == 4)  ghost.changeColor();
    }
    */
}
