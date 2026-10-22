class Pacman {
    float x, y;
    int turbo;
    float angle = 0;
    int r = 255, g = 220, b = 0;
    int colorCount = 0;

    Pacman(float x, float y, int t) {
        this.x = x;
        this.y = y;
        this.turbo = t;
    }

    void move(float dx, float dy) {
        if( ( x+dx > pW && x+dx < (fieldW+pW) ) && ( y+dy > pH && y+dy < (fieldH+pH) ) ){
          x += dx;
          y += dy;
          angle = atan2(dy, dx);
        }
    }
    
    void changeTurbo(int t){
      turbo += t;
    }
    
    void changeColor(){
      
      if(colorCount < 4){
        colorCount++;
      }else{
        colorCount = 0;
      }
      
      switch(colorCount){
          case 0:
            this.r = 255;
            this.g = 220;
            this.b = 0;
            break;
          case 1:
            this.r = 0;
            this.g = 255;
            this.b = 242;
            break;
          case 2:
            this.r = 139;
            this.g = 172;
            this.b = 15;
            break;
          case 3:
            this.r = 212;
            this.g = 175;
            this.b = 55;
            break;
      }
    }

    void display() {
        noStroke();
        fill(r, g, b);
        arc(x, y, 40, 40, angle + QUARTER_PI / 2, angle + TWO_PI - QUARTER_PI / 2, PIE);
    }
}
