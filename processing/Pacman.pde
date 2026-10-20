class Pacman {
    float x, y;
    float angle = 0;

    Pacman(float x, float y) {
        this.x = x;
        this.y = y;
    }

    void move(float dx, float dy) {
        if( ( x+dx > pW && x+dx < (fieldW+pW) ) && ( y+dy > pH && y+dy < (fieldH+pH) ) ){
          x += dx;
          y += dy;
          angle = atan2(dy, dx);
        }
    }

    void display() {
        noStroke();
        fill(255, 220, 0);
        arc(x, y, 40, 40, angle + QUARTER_PI / 2, angle + TWO_PI - QUARTER_PI / 2, PIE);
    }
}
