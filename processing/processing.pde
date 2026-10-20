int numDots = 10;
float[] dotX = new float[numDots];
float[] dotY = new float[numDots];

Pacman pacman;

void setup() {
    size(1000, 830);
    pacman = new Pacman(500, 415);
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
}

void keyPressed() {
    if (keyCode == UP) pacman.move(0, -10);
    if (keyCode == DOWN) pacman.move(0, 10);
    if (keyCode == LEFT) pacman.move(-10, 0);
    if (keyCode == RIGHT) pacman.move(10, 0);
}
