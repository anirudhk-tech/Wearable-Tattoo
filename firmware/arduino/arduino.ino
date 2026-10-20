/*
  MPR121 touch test - all 12 electrodes (0 to 11).
  Prints "Sensor N touched" when the pad on electrode N is touched.

  Wiring: VIN->3.3V, GND->GND, SDA->SDA, SCL->SCL, copper pads -> electrodes 0..11
  Serial Monitor: 115200 baud. Keep hands off all pads while powering up.
*/

#include <Wire.h>
#include "Adafruit_MPR121.h"

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_SENSORS = 12;
const int DROP_THRESHOLD = 5;   // how far the reading must fall to count as a touch

int  softBaseline[NUM_SENSORS];
bool wasTouched[NUM_SENSORS];

void setup() {
  Serial.begin(115200);
  delay(10);

  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found - check wiring.");
    while (1) delay(10);
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

  Serial.println("Ready. Touch any pad (0-11).");
}

void loop() {
  uint16_t chipTouched = cap.touched();   // bit s = electrode s

  for (int s = 0; s < NUM_SENSORS; s++) {
    // Touch if the chip reports it OR the reading drops below our baseline
    bool chipSaysTouched = chipTouched & (1 << s);
    bool dropped = (softBaseline[s] - (int)cap.filteredData(s)) > DROP_THRESHOLD;
    bool touched = chipSaysTouched || dropped;

    if (touched && !wasTouched[s]) {
      Serial.print("Sensor ");
      Serial.print(s);
      Serial.println(" touched");
    }
    wasTouched[s] = touched;
  }

  delay(10);
} 
