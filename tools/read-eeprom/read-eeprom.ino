/* TEMPORARY EEPROM READER - read only, never writes EEPROM.
 * Holds all 4 servos at exactly the same rest pose the original firmware
 * would command, so the arm does not go limp while this sketch is resident.
 */
#include <EEPROM.h>
#include <Servo.h>

struct Calibration
{
  float baseAngle;
  float shoulderAngle;
  float elbowAngle;
  float gripperOpenAngle;
  float gripperCloseAngle;
};

Servo baseServo, shoulderServo, elbowServo, gripperServo;

float guard(float v) { return isnan(v) ? 0.0f : v; }

void setup()
{
  Serial.begin(115200);

  Calibration c;
  EEPROM.get(0, c);
  c.baseAngle          = guard(c.baseAngle);
  c.shoulderAngle      = guard(c.shoulderAngle);
  c.elbowAngle         = guard(c.elbowAngle);
  c.gripperOpenAngle   = guard(c.gripperOpenAngle);
  c.gripperCloseAngle  = guard(c.gripperCloseAngle);

  // Hold the same rest pose as roboticArm.cpp begin() -- identical constrain
  // limits and Reverse handling, so nothing jumps while we are resident.
  int b {constrain((int)(90.0f + c.baseAngle),     0,  180)};
  int s {constrain((int)(90.0f + c.shoulderAngle), 0,  110)};
  int e {constrain((int)(90.0f + c.elbowAngle),   20,  180)};
  int g {constrain((int)c.gripperOpenAngle,        0,  100)};

  baseServo.write(b);              baseServo.attach(6);
  shoulderServo.write(s);          shoulderServo.attach(9);
  elbowServo.write(180 - e);       elbowServo.attach(10);   // Reverse
  gripperServo.write(180 - g);     gripperServo.attach(11); // Reverse

  delay(300);
  Serial.println(F("=== EEPROM READER (read-only) ==="));

  Serial.print(F("raw[0..19]:"));
  for (int i = 0; i < 20; ++i)
  {
    byte v {EEPROM.read(i)};
    Serial.print(' ');
    if (v < 16) Serial.print('0');
    Serial.print(v, HEX);
  }
  Serial.println();

  Serial.print(F("calib_base      = ")); Serial.println(c.baseAngle, 6);
  Serial.print(F("calib_shoulder  = ")); Serial.println(c.shoulderAngle, 6);
  Serial.print(F("calib_elbow     = ")); Serial.println(c.elbowAngle, 6);
  Serial.print(F("gripper_open    = ")); Serial.println(c.gripperOpenAngle, 6);
  Serial.print(F("gripper_close   = ")); Serial.println(c.gripperCloseAngle, 6);

  int written {0};
  for (int i = 0; i < 1024; ++i) if (EEPROM.read(i) != 0xFF) ++written;
  Serial.print(F("non-0xFF bytes / 1024 = ")); Serial.println(written);

  Serial.print(F("servos held at base/shoulder/elbow/gripper = "));
  Serial.print(b); Serial.print('/'); Serial.print(s); Serial.print('/');
  Serial.print(e); Serial.print('/'); Serial.println(g);
  Serial.println(F("DONE"));
}

void loop() {}
