/*
  SNAKE//SKIN  -  Smart Tattoo controller firmware
  Board : DFRobot FireBeetle ESP32 + Adafruit MPR121

  Flash the SAME sketch on both devices, changing only DEVICE_ID:
    Device 1 -> 'A'  (10 pads: P1 movement + game controls)
    Device 2 -> 'B'  (4-10 pads: P2 movement + extras)

  Touch detection = your tested logic: the chip's own touch flag OR a drop of
  the filtered reading below a per-pad software baseline taken at boot.

  Wiring (I2C): VIN->3.3V, GND->GND, SDA->SDA, SCL->SCL, copper pads -> electrodes 0..9
  Keep hands OFF all pads while powering up (baseline is measured at boot).

  Serial protocol (115200 baud), one line per update:
    T,<ID>,<bitmask>\n      e.g.  T,A,5   -> pads 0 and 2 touched
  Set VERBOSE true to also print "Sensor N touched" for wiring checks
  (the game ignores those lines).
*/

#include <Wire.h>
#include "Adafruit_MPR121.h"

#define DEVICE_ID 'A'          // <-- change to 'B' for the second device
#define VERBOSE   false

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_SENSORS    = 10;   // electrodes 0-9 are used by the game
const int DROP_THRESHOLD = 5;    // how far the reading must fall to count as a touch

int  softBaseline[NUM_SENSORS];
bool wasTouched[NUM_SENSORS];

uint16_t lastMask = 0xFFFF;
unsigned long lastSend = 0;

void setup() {
  Serial.begin(115200);
  delay(10);

  while (!cap.begin(0x5A)) {
    Serial.println("ERR,MPR121 not found - check wiring");
    delay(1000);
  }

  // Restart sensing so the chip settles, then take our own baseline per pad
  cap.writeRegister(MPR121_ECR, 0x00);
  delay(200);
  cap.writeRegister(MPR121_ECR, 0x8F);
  delay(500);

  for (int s = 0; s < NUM_SENSORS; s++) {
    long sum = 0;
    for (int i = 0; i < 20; i++) { sum += cap.filteredData(s); delay(5); }
    softBaseline[s] = sum / 20;
    wasTouched[s] = false;
  }

  Serial.println("READY");
}

void loop() {
  uint16_t chipTouched = cap.touched();   // bit s = electrode s
  uint16_t mask = 0;

  for (int s = 0; s < NUM_SENSORS; s++) {
    bool chipSaysTouched = chipTouched & (1 << s);
    bool dropped = (softBaseline[s] - (int)cap.filteredData(s)) > DROP_THRESHOLD;
    bool touched = chipSaysTouched || dropped;

    if (touched) mask |= (1 << s);

#if VERBOSE
    if (touched && !wasTouched[s]) {
      Serial.print("Sensor ");
      Serial.print(s);
      Serial.println(" touched");
    }
#endif
    wasTouched[s] = touched;
  }

  // send on change, plus a 100 ms heartbeat so the game knows we're alive
  unsigned long now = millis();
  if (mask != lastMask || now - lastSend > 100) {
    Serial.print("T,");
    Serial.print((char)DEVICE_ID);
    Serial.print(",");
    Serial.println(mask);
    lastMask = mask;
    lastSend = now;
  }

  delay(10);
}
