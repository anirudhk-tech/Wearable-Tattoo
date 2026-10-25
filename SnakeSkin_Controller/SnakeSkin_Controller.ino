/*
  SNAKE//SKIN  -  Smart Tattoo controller firmware
  Board : ESP32 (e.g. DFRobot FireBeetle ESP32) + Adafruit MPR121
          (+ optional Spectra Symbol FS-L-0055-253-ST force strip)

  TWO OUTPUT MODES (set GAME_MODE below):
    GAME_MODE false -> Serial Monitor mode. Prints ONLY when something happens:
                         Sensor 1 touched
                         Strip pressed: force 412
                       Nothing is printed while idle.
    GAME_MODE true  -> data stream for the Processing game (T,... and F,... lines).
                       The game needs this stream, so set it to true when you play.

  Flash the SAME sketch on both devices, changing only DEVICE_ID / HAS_FSLP:
    Device 1 -> DEVICE_ID 'A', HAS_FSLP 1   (10 pads + force strip)
    Device 2 -> DEVICE_ID 'B', HAS_FSLP 0   (10 pads)

  Keep hands OFF all pads while powering up (baseline is measured at boot).

  FORCE STRIP WIRING (3.3V logic) - voltage divider, only 3 connections:
    3V3 -------- strip pin (one end of the strip)
    A0  -------- strip SL pin (the wiper), and the same node goes through
                 resistor Ro (4.7k-10k) to GND
    Pressing harder lowers the strip resistance, so the A0 voltage RISES.
    No touch -> A0 is pulled to ~0 by Ro. This gives force only (no position).
*/

#include <Wire.h>
#include "Adafruit_MPR121.h"

#define DEVICE_ID 'A'          // <-- 'A' or 'B'
#define HAS_FSLP  1            // <-- 1 if this device has the force strip
#define GAME_MODE true         // <-- true = Processing game (default), false = readable Serial Monitor

#define FSLP_SL  A0            // strip signal -> A0
#define FSLP_TOUCH_MIN   60    // force counts below this = not pressed (lower = more sensitive)
#define STRIP_PRINT_DELTA 40   // Serial Monitor: print again only if force changed this much
#define STRIP_DEBUG false      // true = also print the raw A0 reading 4x/second (wiring check)

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_SENSORS    = 10;
const int DROP_THRESHOLD = 5;

int  softBaseline[NUM_SENSORS];
bool wasTouched[NUM_SENSORS];

uint16_t lastMask = 0xFFFF;
unsigned long lastSend = 0;
unsigned long lastStrip = 0;
bool stripDown = false;
int lastPrintedForce = 0;

// ESP32 has a 12-bit ADC (0-4095). Other boards are 10-bit, so scale to 0-4095.
#if defined(ARDUINO_ARCH_ESP32)
  #define ADC_SHIFT 0
#else
  #define ADC_SHIFT 2
#endif

#if HAS_FSLP
int readForce() {
  long sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(FSLP_SL);
  return (sum / 8) << ADC_SHIFT;
}
#endif

void setup() {
  Serial.begin(115200);
  delay(10);

  while (!cap.begin(0x5A)) {
    Serial.println("ERR,MPR121 not found - check wiring");
    delay(1000);
  }

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

#if HAS_FSLP
#if defined(ARDUINO_ARCH_ESP32)
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);       // full 0-3.3 V range
#endif
  pinMode(FSLP_SL, INPUT);
#endif

#if GAME_MODE
  Serial.println("READY");
#endif
}

void loop() {
  uint16_t chipTouched = cap.touched();
  uint16_t mask = 0;

  for (int s = 0; s < NUM_SENSORS; s++) {
    bool chipSaysTouched = chipTouched & (1 << s);
    bool dropped = (softBaseline[s] - (int)cap.filteredData(s)) > DROP_THRESHOLD;
    bool touched = chipSaysTouched || dropped;

    if (touched) mask |= (1 << s);

#if !GAME_MODE
    if (touched && !wasTouched[s]) {    // print once per touch, nothing else
      Serial.print("Sensor ");
      Serial.print(s);
      Serial.println(" touched");
    }
#endif
    wasTouched[s] = touched;
  }

  unsigned long now = millis();

#if GAME_MODE
  if (mask != lastMask || now - lastSend > 100) {   // change + 100 ms heartbeat
    Serial.print("T,");
    Serial.print((char)DEVICE_ID);
    Serial.print(",");
    Serial.println(mask);
    lastMask = mask;
    lastSend = now;
  }
#endif

#if HAS_FSLP
  if (now - lastStrip >= 30) {          // ~33 Hz
    int force = readForce();
    lastStrip = now;

#if GAME_MODE
    Serial.print("F,");
    Serial.print((char)DEVICE_ID);
    Serial.print(",");
    Serial.println(force);
#else
#if STRIP_DEBUG
    static unsigned long lastDbg = 0;
    if (now - lastDbg > 250) {
      Serial.print("[strip raw A0 force=");
      Serial.print(force);
      Serial.println("]");
      lastDbg = now;
    }
#endif
    bool down = force >= FSLP_TOUCH_MIN;
    if (down && (!stripDown || abs(force - lastPrintedForce) >= STRIP_PRINT_DELTA)) {
      Serial.print("Strip pressed: force ");
      Serial.println(force);
      lastPrintedForce = force;
    }
    stripDown = down;
#endif
  }
#endif

  delay(5);
}
