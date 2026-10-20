int numDots = 10;
float[] dotX = new float[numDots];
float[] dotY = new float[numDots];

Snake snake;

void setup() {
    size(1000, 830);
    snake = new Snake(500, 415, 15);
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

    snake.display();
}

void keyPressed() {
    if (keyCode == UP) snake.move(0, -10);
    if (keyCode == DOWN) snake.move(0, 10);
    if (keyCode == LEFT) snake.move(-10, 0);
    if (keyCode == RIGHT) snake.move(10, 0);
}
