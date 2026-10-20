int numDots = 10;
float[] dotX = new float[numDots];
float[] dotY = new float[numDots];

Pacman pacman;
Ghost ghost;

void setup() {
    size(1000, 830);
    setupSerial();
    resetGame();
}

void resetGame() {
    pacman = new Pacman(500, 415);
    ghost = new Ghost(600, 415);
    for (int i = 0; i < numDots; i++) {
        dotX[i] = random(300, 700);
        dotY[i] = random(200, 500);
    }
}


void draw() {
    background(255);
    stroke(0);

    fill(0, 0, 0);
    rect(200, 165, 300, 500);

    fill(0, 0, 0);
    rect(500, 165, 300, 500);

    fill(255, 0, 0);
    noStroke();
    for (int i = 0; i < numDots; i++) {
        ellipse(dotX[i], dotY[i], 10, 10);
    }

    pacman.display();
    ghost.display();
}
