class Snake {
    float x, y;
    int len;

    Snake(float x, float y, int len) {
        this.x = x;
        this.y = y;
        this.len = len;
    }

    void setLength(int n) {
        len = max(n, 1);
    }

    void display() {
        noStroke();
        fill(30, 90, 30);
        for (int i = 0; i < len; i++) {
            ellipse(x - i * 10, y, 12, 12);
        }
    }
}
