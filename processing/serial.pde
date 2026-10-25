import processing.serial.*;

String PACMAN_PORT_NAME = "/dev/ttyACM0";
String GHOST_PORT_NAME = "/dev/ttyACM1";
int baudrate = 115200;
Serial pacmanPort;
Serial ghostPort;
String[] items = new String[2];
int offset = 20;

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
    
    if (p == pacmanPort) {
      println("PACMAN serial: " + line);
    } else {
      println("GHOST serial: " + line);
    }
    
    items = split(line, ", ");
    line = items[0];

    if (match(line, "^\\d+$") == null) return;

    int sensor = int(line);
    int SpectraSensor = int(items[1]);

    float dx = 0;
    float dy = 0;
    if (sensor == 0) dy = -10;
    if (sensor == 1) dy = 10;
    if (sensor == 2) dx = -10;
    if (sensor == 3) dx = 10;
    
    if (sensor == 5 && numDots < maxDots){  //increase dots
      dots[numDots] = new Dot(int(random(pW/10, (pW+fieldW)/10)) * 10, int(random(pH/10, (pH+fieldH)/10)) * 10);
      numDots++;
    }
    if (sensor == 6 && numDots > minDots) numDots--; //decrease dots
    
    if (sensor == 9) {
        resetGame();
        return;
    }

    if (p == pacmanPort){
      if ( sensor == 8 ) pacman.setMaxTurbo();
      
      if(SpectraSensor > 230 + offset ||  SpectraSensor < 230 - offset ){
       turbo = true; 
      }else{
       turbo = false; 
      }
      
      if( pacman.turbo > 1 && turbo ){
        dx *= 2;
        dy *= 2;
        pacman.changeTurbo(-2);
      }
      
      if( sensor == 7 ){
        pacman.changePosition(int(random(pW, (pW+fieldW))), int(random(pH, (pH+fieldH))));
      }else{
        pacman.move(dx, dy);
      }
      checkPoints();
      checkGameOver();
      if (sensor == 4)  pacman.changeColor();
    }
    
    /**/
    if (p == ghostPort){
      if ( sensor == 8 ) pacman.setMaxTurbo();
      
      if( ghost.turbo > 1 && (SpectraSensor > 250 + offset ||  SpectraSensor < 250 - offset)){
        dx *= 2;
        dy *= 2;
        ghost.changeTurbo(-2);
      }
      
      if( sensor == 7 ){
        ghost.changePosition(int(random(pW, (pW+fieldW))), int(random(pH, (pH+fieldH))));
      }else{
        ghost.move(dx, dy);
      }
      checkGameOver();
      if (sensor == 4)  ghost.changeColor();
    }
   
}
