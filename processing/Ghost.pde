class Ghost {
    float x, y;
    int turbo;
    int r = 0, g = 200, b = 255;
    int colorCount;

    Ghost(float x, float y, int t) {
        this.x = x;
        this.y = y;
        this.turbo = t;
    }

    void move(float dx, float dy) {
        if( ( x+dx > pW && x+dx < (fieldW+pW) ) && ( y+dy > pH && y+dy < (fieldH+pH) ) ){
          x += dx;
          y += dy;
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
            this.r = 0;
            this.g = 200;
            this.b = 255;
            break;
          case 1:
            this.r = 57;
            this.g = 255;
            this.b = 20;
            break;
          case 2:
            this.r = 255;
            this.g = 117;
            this.b = 24;
            break;
          case 3:
            this.r = 106;
            this.g = 13;
            this.b = 173;
            break;
      }
    }

    void display() {
        noStroke();
        fill(r, g, b);
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
