#include <Wire.h>
#include <Servo.h>

int xzChange = 0;

const char GYRO = 0x69;
const char SMPLRT_DIV = 0X15;
const char DLPF_FS = 0X16;
const char GYRO_XOUT_H = 0x1D;
const char GYRO_XOUT_L = 0x1E;
const char GYRO_YOUT_H = 0x1F;
const char GYRO_YOUT_L = 0x20;
const char GYRO_ZOUT_H = 0x21;
const char GYRO_ZOUT_L = 0x22;

const char ACCEL = 0x40;
const char ACCEL_XOUT_H = 0x03;
const char ACCEL_XOUT_L = 0x02;
const char ACCEL_YOUT_H = 0x05;
const char ACCEL_YOUT_L = 0x04;
const char ACCEL_ZOUT_H = 0x07;
const char ACCEL_ZOUT_L = 0x06;

const boolean DEBUG = false;
const int INTERVAL = 5;
//const int SERIAL_SPD = 9600;
const int LF = 10;

const int ROLL = 0;
const int PITCH = 1;

int offx = 0;
int offy = 0;
int offz = 0;
long gyroTime = 0;

long stopWatch = 0;
long timer = 0;

boolean firstSample = true;

float Accel[3];
float LinAccel[3];
float LinVelocity[3];
float gravMagnitude = 0;
float RwAcc[3];
float Gyro[3];     //Gyro readings
float RwGyro[3];   //Rw obtained from last estimated value and gyro movement
float Awz[2];      //angles between projection of R on XZ/YZ plane and Z axis (deg)
float RwEst[3];

float KangleX = 0;
float KangleY = 0;

float wGyro = 20.0;

Servo motor[4];
int mastpwm = 1000;
int modpwm[4];
float RangleX = 0;
float RangleY = 0;
float xzDesiredAngle = 0;
float yzDesiredAngle = 0;
float offxz = 0;
float offyz = 0;
float xzTrim = 0;
float yzTrim = 0;

int i = 0;
int printCounter = 0;

boolean clientConnected = false;
long keepAliveTimer = 0;

float angleCo = 3;
float rateCo = 1.5f;
boolean modeStopRoll = true;
boolean rollSign = false;
boolean modeStopPitch = true;
boolean pitchSign = false;
union floatConversion {int i; float f; };
boolean atMinAlt = false;
int startTime = 0;

void setup() {
  motor[0].attach(10);
  motor[1].attach(5);
  motor[2].attach(6);
  motor[3].attach(9);
  for (i = 0; i < 4; i++) {
    motor[i].writeMicroseconds(mastpwm);
  }
  Wire.begin();
  i2cWrite(GYRO, DLPF_FS, 0x19);
  i2cWrite(GYRO, SMPLRT_DIV, 0x02);
//  i2cWrite(ACCEL, 0x20, 0x38);
  i2cWrite(ACCEL, 0x20, 0x58);
  delay(100);
  findGravity();
  gyroZeroCalibrate();
  gyroTime = millis();
  setHover();
  int serial_spd = 0;
  if (DEBUG) {
    serial_spd = 115200;
  }
  else {
    serial_spd = 9600;
  }
  Serial.begin(serial_spd);
  Serial.flush();
}

void loop() {
  while (!clientConnected && !DEBUG) {
    getPilotData();
    atMinAlt = true;
    startTime = 0;
    if (clientConnected) {
      keepAliveTimer = millis();
    }
  }

  stopWatch = millis();
  timer = millis();

  getGyro();
//  RangleX += Gyro[0] * (INTERVAL/1000.0f);
//  RangleY += Gyro[1] * (INTERVAL/1000.0f);
  getAccel();
  getInclination();
  getLinAccel();
  getLinVelocity();
  getPilotData();

//  if (xzDesiredAngle == 0 && yzDesiredAngle == 0) {
//    autoTrim();
//  }
//  if (mastpwm > 1600 && startTime == 0) {
//    startTime = millis();
//  }
//  if (millis() - startTime > 5000) {
//    atMinAlt = true;
//  }
  setMotors();

  if (DEBUG && (printCounter%5) == 0) {
    stopWatch = millis() - stopWatch;
    Serial.print(stopWatch);
    Serial.print(",");
    printDebug();
  }

  if (!DEBUG && (millis() - keepAliveTimer) > 1500) {
    setClimbRate(1000);
    setMotors();
    clientConnected = false;
    //    while(true);  //quit program
  }

  while (millis() - timer < INTERVAL) {
    delay(1);
  }
  printCounter++;
}

//  Control protocol:
//  S  indicates start of control packet
//  c  climb_rate(int)
//  p  pitch(float)
//  r  roll(float)
//  y  yaw_rate(int)
//  k  keep-alive
//  b  begin (client has connected)
//  a  angle coeficient(float)
//  g  rate coeficient(float)
//  d  request debug
void getPilotData() {
  if (Serial.available() >= 7) {
    while (Serial.available() >= 6 && Serial.read() != 'S');

    if (Serial.available() >= 6) {
      int tempData = 0;
      int checksum = 0;
      char code = Serial.read();
      tempData = serialReadInt();
      checksum = Serial.read();
      if (abs(tempData%255) != checksum) {
        Serial.print("SB");
      }
      else {
        Serial.print("SG");
        switch(code) {
        case 'c':
          setClimbRate(tempData);
          break;
        case 'p':
          yzDesiredAngle = intBitsToFloat(tempData);
          break;
        case 'r':
          xzDesiredAngle = intBitsToFloat(tempData);
          break;
        case 'y':
          break;
        case 'k':
          // keep-alive, do nothing
          break;
        case 'b':
          clientConnected = true;
          break;
        case 'a':
          angleCo = intBitsToFloat(tempData);
          break;
        case 'g':
          rateCo = intBitsToFloat(tempData);
          break;
        case 'd':
          printDebug();
          break;
        }
        keepAliveTimer = millis();
      }
    }
    else {
      Serial.print("SB");
    }
  }
}

int serialReadInt() {
  int temp = Serial.read() << 24;
  temp |= Serial.read() << 16;
  temp |= Serial.read() << 8;
  temp |= Serial.read();
  return temp;
}

float intBitsToFloat(int bits) {
  union floatConversion u;
  u.i = bits;
  return u.f;
}

void autoTrim() {
  if (mastpwm > 1400) {
    if (abs(LinAccel[0]) > 0) {
  xzTrim = map(LinAccel[0],-4,4,45,-45);
    }
    if (abs(LinAccel[1]) > 0) {
  yzTrim = map(LinAccel[1],-4,4,45,-45);
    }
  }
//  if (mastpwm > 1400) {
//    xzTrim += -1*LinAccel[0];
//    yzTrim += -1*LinAccel[1];
//  }
  if (mastpwm == 1000) {
    xzTrim = 0;
    yzTrim = 0;
  }
}

void setMotors() {
//  int xzChange = 0;
  int yzChange = 0;
  int yawChange = 0;
  const int XZ_MIN_FIX = 25;
  int xzCorrection = 0;
  int temp1 = 0;
  int temp2 = 0;
  int xzDesiredRoll = 0;
  int xzError = 0;
  int yzError = 0;

  if (mastpwm > 1050) {
    //  Gyro[] pos right
    
//    temp1 = RangleX - (xzDesiredAngle+xzTrim);
//    temp2 = XZ_MIN_FIX - ((int((RangleX - (xzDesiredAngle-xzTrim))) & 0x80000000) >> 31 + 1 * -1) * XZ_MIN_FIX;
//    xzChange = rateCo * (Gyro[0] + (angleCo*temp1 + temp2));

//    yzChange = rateCo * (Gyro[1] + ((RangleY - (yzDesiredAngle+yzTrim))*angleCo));
//    xzChange = angleCo * (RangleX - (xzDesiredAngle-xzTrim)) + rateCo * Gyro[0];
//    yzChange = angleCo * (RangleY - (yzDesiredAngle-yzTrim)) + rateCo * Gyro[1];
//    xzCorrection = angleCo * (RangleX - (xzDesiredAngle-xzTrim));// + (XZ_MIN_FIX - ((int((RangleX - (xzDesiredAngle-xzTrim))) & 0x80000000) >> 31 + 1 * -1) * XZ_MIN_FIX);
//    xzChange = rateCo * (Gyro[0] + xzCorrection);
//    xzChange = rateCo * (Gyro[0] - xzDesiredAngle);
//    yzChange = rateCo * (Gyro[1] - yzDesiredAngle);
    
    // This one decent
//    if(atMinAlt) {
//      //  Roll Correct
//    if (modeStopRoll) {
//      if ((Gyro[0] > 0) == rollSign) {
//        modeStopRoll = false;
//        rollSign = RangleX > 0;
//      }
//      else {
//        xzChange = rateCo * Gyro[0];
//      }
//    }
//    else {
//      if ((RangleX > 0) != rollSign) {
//        modeStopRoll = true;
//      }
//      else {
//      xzChange = angleCo * (RangleX - (xzDesiredAngle-xzTrim));
//      }
//    }
//    //  Pitch Correct
//    if (modeStopPitch) {
//      if ((Gyro[1] > 0) == pitchSign) {
//        modeStopPitch = false;
//        pitchSign = RangleY > 0;
//      }
//      else {
//        yzChange = rateCo * Gyro[1];
//      }
//    }
//    else {
//      if ((RangleY > 0) != pitchSign) {
//        modeStopPitch = true;
//      }
//      else {
//      yzChange = angleCo * (RangleY - (yzDesiredAngle-yzTrim));
//      }
//    }
//    }
//    else {
//      xzChange = rateCo * Gyro[0];
//      yzChange = rateCo * Gyro[1];
//    }

//    xzError = RangleX - xzDesiredAngle;
//    yzError = RangleY - yzDesiredAngle;
//    if (xzError > 0) {
//      xzChange = rateCo * (Gyro[0] - 50);
//    }
//    else {
//      xzChange = rateCo * (Gyro[0] + 50);
//    }

    // This one pretty good
    xzChange = rateCo * (Gyro[0] + map(RangleX - xzDesiredAngle,-45,45,angleCo*-1,angleCo));
    yzChange = rateCo * (Gyro[1] + map(RangleY - yzDesiredAngle,-45,45,angleCo*-1,angleCo));

//    if (abs(Gyro[0]) > 10 && (Gyro[0] > 0) == (RangleX > 0)) {
//      xzChange = rateCo * Gyro[0];
//    }
//    else { // ((Gyro[0] < 0) && (RangleX > 0)) {
////      xzChange = rateCo * (Gyro[0] + angleCo * (RangleX - (xzDesiredAngle-xzTrim)));
//      xzChange = angleCo * (RangleX - (xzDesiredAngle-xzTrim));
//    }
    
//    xzDesiredRoll = angleCo * (xzDesiredAngle-RangleX);
//    if (xzDesiredRoll > 0) {
//      xzDesiredRoll += 50;
//    }
//    else {
//      xzDesiredRoll -= 50;
//    }
//    xzChange = rateCo * (Gyro[0] + -25);
//    if(KangleX-xzDesiredAngle > 0) {
//      xzChange *= -1;
//    }
//    xzChange *= -1;
    
    yawChange = rateCo * Gyro[2];

    modpwm[0] = constrain(mastpwm - xzChange - yzChange + yawChange, 1050, 2000);
    modpwm[1] = constrain(mastpwm + xzChange - yzChange - yawChange, 1050, 2000);
    modpwm[2] = constrain(mastpwm + xzChange + yzChange + yawChange, 1050, 2000);
    modpwm[3] = constrain(mastpwm - xzChange + yzChange - yawChange, 1050, 2000);
  }
  else {
    for (i = 0; i < 4; i++) {
      modpwm[i] = mastpwm;
    }
  }

  for (i = 0; i < 4; i++) {
    motor[i].writeMicroseconds(modpwm[i]);
  }
}

void setClimbRate(int rate) {
  if (mastpwm != rate) {
    mastpwm = rate;
  }
}

void setAngle(float xz, float yz) {
  xzDesiredAngle = xz;
  yzDesiredAngle = yz;
}

void setHover() {
  xzDesiredAngle = 0;
  yzDesiredAngle = 0;
}

void printDebug() {
  char delimeter = ',';
//  int tempTime = millis();
  Serial.print(Gyro[0]);
  Serial.print(delimeter);
  Serial.print(Gyro[1]);
  Serial.print(delimeter);
  Serial.print(Gyro[2]);
  Serial.print(delimeter);
  Serial.print(Accel[0]);
  Serial.print(delimeter);
  Serial.print(Accel[1]);
  Serial.print(delimeter);
  Serial.print(Accel[2]);
  Serial.print(delimeter);
  Serial.print(LinAccel[0]);
  Serial.print(delimeter);
  Serial.print(LinAccel[1]);
  Serial.print(delimeter);
  Serial.print(Accel[2]);
  Serial.print(delimeter);
  Serial.print(LinVelocity[0]);
  Serial.print(delimeter);
  Serial.print(LinVelocity[1]);
  Serial.print(delimeter);
  Serial.print(RangleX);
  Serial.print(delimeter);
  Serial.print(RangleY);
  Serial.print(delimeter);
  Serial.print(mastpwm);
  Serial.print(delimeter);
  Serial.print(xzChange);
//  Serial.print('\t');
//  tempTime = millis() - tempTime;
//  Serial.print(delimeter);
//  Serial.print(tempTime);
  Serial.print('\n');
}

unsigned char i2cRead(char address, char registerAddress) {
  unsigned char data=0;

  Wire.beginTransmission(address);
  Wire.send(registerAddress);
  Wire.endTransmission();

  Wire.beginTransmission(address);
  Wire.requestFrom(address, 1);

  if(Wire.available()){
    data = Wire.receive();
  }
  Wire.endTransmission();
  return data;
}

void i2cWrite(char address, char registerAddress, char data) {
  Wire.beginTransmission(address);
  Wire.send(registerAddress);
  Wire.send(data);
  Wire.endTransmission();
}

void gyroZeroCalibrate() {
  for (i = 0; i < 100; i++) {
    offx -= readGyroX();
    offy -= readGyroY();
    offz -= readGyroZ();
    delay(INTERVAL);
  }
  offx /= 100;
  offy /= 100;
  offz /= 100;
}

void findGravity() {
  gravMagnitude = 0;
  for (int i = 0; i < 100; i++) {
    getAccel();
    gravMagnitude += Accel[0] + Accel[1] + Accel[2];
    delay(INTERVAL);
  }
  gravMagnitude /= 100;
}

void getGyro() {
  Gyro[0] = readGyroX() + offx;
  Gyro[1] = readGyroY() + offy;
  Gyro[2] = -1 * readGyroZ() + offz;
  Gyro[0] /= 14.375;
  Gyro[1] /= 14.375;
  Gyro[2] /= 14.375;

  gyroTime = millis();
}

void getAccel() {
  RwAcc[0] = readAccelX();
  RwAcc[1] = -1 * readAccelY();
  RwAcc[2] = readAccelZ();
  RwAcc[0],Accel[0] = (RwAcc[0] * .25) / 1000 * 2;
  RwAcc[1],Accel[1] = (RwAcc[1] * .25) / 1000 * 2;
  RwAcc[2],Accel[2] = (RwAcc[2] * .25) / 1000 * 2;
}

void getLinAccel() {
  LinAccel[0] = Accel[0] - gravMagnitude * sin(radians(RangleX));
  LinAccel[1] = Accel[1] - gravMagnitude * sin(radians(RangleY));
//  LinAccel[2] = Accel[2] - gravMagnitude * 
}

void getLinVelocity() {
  for (int i = 0; i < 3; i++) {
    LinVelocity[i] += LinAccel[i]*(INTERVAL/1000.0f);
  }
}

void normalize3DVec(float* vector) {
  float R;
  R = sqrt(vector[0]*vector[0] + vector[1]*vector[1] + vector[2]*vector[2]);
  vector[0] /= R;
  vector[1] /= R;  
  vector[2] /= R;  
}

float squared(float x) {
  return x*x;
}

void getInclination() {
  int w = 0;
  float tmpf = 0.0;
  int currentTime, signRzGyro;

  normalize3DVec(RwAcc);

  if (firstSample) { // the NaN check is used to wait for good data from the Arduino
    for(w=0;w<=2;w++) {
      RwEst[w] = RwAcc[w];    //initialize with accelerometer readings
    }
  }
  else{
    //evaluate RwGyro vector
    if(abs(RwEst[2]) < 0.1) {
      for(w=0;w<=2;w++) {
        RwGyro[w] = RwEst[w];
      }
    }
    else {
      //get angles between projection of R on ZX/ZY plane and Z axis, based on last RwEst
      currentTime = millis();
      for(w=0;w<=1;w++){
        tmpf = Gyro[w];                        //get current gyro rate in deg/s
        tmpf *= (currentTime - gyroTime) / 1000.0f;                     //get angle change in deg
        Awz[w] = atan2(RwEst[w],RwEst[2]) * 180 / PI;   //get angle and convert to degrees 
        Awz[w] += tmpf;             //get updated angle according to gyro movement
      }

      //estimate sign of RzGyro by looking in what qudrant the angle Axz is, 
      //RzGyro is pozitive if  Axz in range -90 ..90 => cos(Awz) >= 0
      signRzGyro = ( cos(Awz[0] * PI / 180) >=0 ) ? 1 : -1;

      for(w=0;w<=1;w++){
        RwGyro[0] = sin(Awz[0] * PI / 180);
        RwGyro[0] /= sqrt( 1 + squared(cos(Awz[0] * PI / 180)) * squared(tan(Awz[1] * PI / 180)) );
        RwGyro[1] = sin(Awz[1] * PI / 180);
        RwGyro[1] /= sqrt( 1 + squared(cos(Awz[1] * PI / 180)) * squared(tan(Awz[0] * PI / 180)) );        
      }
      RwGyro[2] = signRzGyro * sqrt(1 - squared(RwGyro[0]) - squared(RwGyro[1]));
    }

    //combine Accelerometer and gyro readings
    for(w=0;w<=2;w++) RwEst[w] = (RwAcc[w] + wGyro * RwGyro[w]) / (1 + wGyro);

    normalize3DVec(RwEst);
  }

  KangleX = degrees(RwEst[0]);
  KangleY = degrees(RwEst[1]);
  RangleX = KangleX+offxz;
  RangleY = KangleY+offyz;
  firstSample = false;
}

int readAccelX() {
  int data=0;
  data = i2cRead(ACCEL, ACCEL_XOUT_H)<<8;
  data |= i2cRead(ACCEL, ACCEL_XOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}

int readAccelY() {
  int data=0;
  data = i2cRead(ACCEL, ACCEL_YOUT_H)<<8;
  data |= i2cRead(ACCEL, ACCEL_YOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}

int readAccelZ() {
  int data=0;
  data = i2cRead(ACCEL, ACCEL_ZOUT_H)<<8;
  data |= i2cRead(ACCEL, ACCEL_ZOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}

int readGyroX() {
  int data=0;
  data = i2cRead(GYRO, GYRO_YOUT_H)<<8;
  data |= i2cRead(GYRO, GYRO_YOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}

int readGyroY() {
  int data=0;
  data = i2cRead(GYRO, GYRO_XOUT_H)<<8;
  data |= i2cRead(GYRO, GYRO_XOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}

int readGyroZ() {
  int data=0;
  data = i2cRead(GYRO, GYRO_ZOUT_H)<<8;
  data |= i2cRead(GYRO, GYRO_ZOUT_L);

  if ((data & 0x8000) != 0) {
    data |= 0xffff0000;
  }

  return data;
}






