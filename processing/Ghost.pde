class Ghost {
    float x, y;

    Ghost(float x, float y) {
        this.x = x;
        this.y = y;
    }

    void move(float dx, float dy) {
        if( ( x+dx > pW && x+dx < (fieldW+pW) ) && ( y+dy > pH && y+dy < (fieldH+pH) ) ){
          x += dx;
          y += dy;
        }
    }

    void display() {
        noStroke();
        fill(0, 200, 255);
        arc(x, y, 40, 40, PI, TWO_PI);
        rect(x - 20, y, 40, 20);

        fill(255);
        ellipse(x - 7, y - 3, 10, 10);
        ellipse(x + 7, y - 3, 10, 10);
        fill(0);
        ellipse(x - 7, y - 3, 4, 4);
        ellipse(x + 7, y - 3, 4, 4);
    }
}
