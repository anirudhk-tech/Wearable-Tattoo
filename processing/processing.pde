int numDots = 10, maxDots = 30, minDots = 5;
int totScore = 0;
int maxTurbo = 100, prevAddTurbo = 0;
int fieldW = 600, fieldH = 500;
int pW = 200, pH = 165;
int killRate = 30;
int dotsRate = 15;
boolean turbo = false;


Pacman pacman;
Ghost ghost;
Dot[] dots = new Dot[maxDots];

// temporary function 
void keyPressed() {
    if (key == 't') turbo = true;
    if (key == 'f') turbo = false;
}

void setup() {
    size(1000, 830);
    setupSerial();
    resetGame();
}

void resetGame() {
  
    pacman = new Pacman(500, 410, maxTurbo);
    ghost = new Ghost(600, 410, maxTurbo);
    
    for (int i = 0; i < numDots; i++) {
        dots[i] = new Dot(int(random(pW/10, (pW+fieldW)/10)) * 10, int(random(pH/10, (pH+fieldH)/10)) * 10);
    }
    
    totScore = 0;
}

void checkPoints(){
  
  for(int i = 0; i < numDots; i++){
    //print("pacman.x: " + pacman.x + " dots[i].x: " + dots[i].x + " pacman.y: " + pacman.y + " dots[i].y: " + dots[i].y + "\n");
    if((pacman.x >= dots[i].x - dotsRate && pacman.x <= dots[i].x + dotsRate) && (pacman.y >= dots[i].y - dotsRate && pacman.y <= dots[i].y + dotsRate) ){
      totScore += 10;
      dots[i].x = int(random(pW/10, (pW+fieldW)/10)) * 10;
      dots[i].y = int(random(pH/10, (pH+fieldH)/10)) * 10;
    }
  }
}

void checkGameOver(){
  if(( pacman.x >= ghost.x - killRate && pacman.x <= ghost.x + killRate) && (pacman.y >= ghost.y - killRate && pacman.y <= ghost.y + killRate ) ){
    resetGame();
  }
}


void draw() {
    background(255);
    stroke(0);
    
    fill(0, 0, 0);
    textSize(20); 
    text("Dots: " + numDots, 475, 45);
    textSize(40); 
    text("Total score: " + totScore, 400, 100);

    fill(0, 0, 0);
    rect(pW-20, pH-20, fieldW+40, fieldH+40);

    fill(255, 0, 0);
    noStroke();
    for (int i = 0; i < numDots; i++) {
        ellipse(dots[i].x, dots[i].y, 10, 10);
    }

    pacman.display();
    ghost.display();
    
    // pacman bar
    fill(0, 0, 0);
    textSize(20); 
    text("Turbo", 200, 65);
    fill(100);
    rect(200, 80, maxTurbo, 30);
    
    fill(255, 50, 50);
    rect(200, 80, pacman.turbo, 30);
    
    // ghost bar
    fill(0, 0, 0);
    textSize(20); 
    text("Turbo", 700, 65);
    fill(100);
    rect(700, 80, maxTurbo, 30);
    
    fill(255, 50, 50);
    rect(700, 80, ghost.turbo, 30);
    
    if(millis() - prevAddTurbo > 1000){
      if( pacman.turbo < maxTurbo ){
        pacman.changeTurbo(1);
      }
      
      if(ghost.turbo < maxTurbo){
        ghost.changeTurbo(1);
      }
      
      prevAddTurbo = millis();
    }
}
