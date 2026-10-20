int numDots = 10;
int totScore = 0;
int fieldW = 600, fieldH = 500;
int pW = 200, pH = 165;

Pacman pacman;
Ghost ghost;
Dot[] dots = new Dot[numDots];

void setup() {
    size(1000, 830);
    setupSerial();
    resetGame();
}

void resetGame() {
    pacman = new Pacman(500, 410);
    ghost = new Ghost(600, 410);
    for (int i = 0; i < numDots; i++) {
        dots[i] = new Dot(int(random(pW/10, (pW+fieldW)/10)) * 10, int(random(pH/10, (pH+fieldH)/10)) * 10);
    }
    
    totScore = 0;
}

void checkPoints(){
  
  for(int i = 0; i < numDots; i++){
    //print("pacman.x: " + pacman.x + " dots[i].x: " + dots[i].x + " pacman.y: " + pacman.y + " dots[i].y: " + dots[i].y + "\n");
    if(pacman.x == dots[i].x && pacman.y == dots[i].y){
      totScore += 10;
      dots[i].x = int(random(pW/10, (pW+fieldW)/10)) * 10;
      dots[i].y = int(random(pH/10, (pH+fieldH)/10)) * 10;
    }
  }
}

void checkGameOver(){
  if(pacman.x == ghost.x && pacman.y == ghost.y){
    resetGame();
  }
}


void draw() {
    background(255);
    stroke(0);
    
    textSize(40); 
    text("Total score: " + totScore, 400, 100);

    fill(0, 0, 0);
    rect(pW, pH, fieldW, fieldH);

    fill(255, 0, 0);
    noStroke();
    for (int i = 0; i < numDots; i++) {
        ellipse(dots[i].x, dots[i].y, 10, 10);
    }

    pacman.display();
    ghost.display();
}
