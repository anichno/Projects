// Need G4P library
import guicomponents.*;
import processing.serial.*;
import procontroll.*;
import net.java.games.input.*;

int quadThrottle = 1000;
float quadAngleCo = 200.0f;
float quadRateCo = 1.5f;
float quadPitchAngle = 0;
float quadRollAngle = 0;

Serial myPort;
int prevQuadThrottle;
float prevAngleCo;
float prevRateCo;
float prevPitchAngle;
float prevRollAngle;
int keepAliveTimer = 0;
int sendTimer = 0;
int saveTimer = 0;
int saveDebugTime = 0;
final int MIN_SEND_TIME = 20;
final int SERIAL_SPD = 9600;

final int ANGLE_CONTROL_CENTER_X = 350;
final int ANGLE_CONTROL_CENTER_Y = 125;

int angleControlX = ANGLE_CONTROL_CENTER_X;
int angleControlY = ANGLE_CONTROL_CENTER_Y;
boolean angleInControl = false;

float trimRoll = 0;
float trimPitch = 0;

ControllStick joystick;
ControllSlider joystickThrottle;
boolean joystickConnected = false;

boolean requestDebug = false;
String debugData = "";

void setup() {
  size(480, 320);
  createGUI();
  customGUI();
  // Place your setup code here

  ControllIO controll = ControllIO.getInstance(this);
  ControllDevice device = null;
  try {
    device = controll.getDevice("Cyborg F.L.Y.5 Flight Stick");
    device.setTolerance(0.05f);
    ControllSlider sliderX = device.getSlider(1);
    ControllSlider sliderY = device.getSlider(0);
    joystickThrottle = device.getSlider(4);
    joystick = new ControllStick(sliderX, sliderY);
    joystickConnected = true;
  }
  catch (Exception e) {
    device = null;
    joystickConnected = false;
  }

  rectMode(CENTER);
  println("Connecting...");
  println(Serial.list());
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, SERIAL_SPD);
  sendUpdate(myPort, 'b', 0);
  while (joystickConnected && joystickThrottle.getValue () != 1);
  saveTimer = millis();
  saveDebugTime = millis();
}

void draw() {
  background(200, 220, 200);

  if (joystickConnected) {
    quadRollAngle = map(joystick.getX(), -1, 1, -45, 45) + trimRoll;
    quadPitchAngle = map(joystick.getY(), -1, 1, -45, 45) + trimPitch;
    quadThrottle = int(map(joystickThrottle.getValue(), 1, -1, 1000, 2000));
  }

  //  if (mousePressed && (angleInControl || abs(mouseX - angleControlX) <= 20 && abs(mouseY - angleControlY) <= 20)) {
  //    angleControlX = constrain(mouseX, ANGLE_CONTROL_CENTER_X-75+10, ANGLE_CONTROL_CENTER_X+75-10);
  //    angleControlY = constrain(mouseY, ANGLE_CONTROL_CENTER_Y-75+10, ANGLE_CONTROL_CENTER_Y+75-10);
  //    quadRollAngle = map(mouseX, ANGLE_CONTROL_CENTER_X-75, ANGLE_CONTROL_CENTER_X+75, -45, 45);
  //    quadPitchAngle = map(mouseY, ANGLE_CONTROL_CENTER_Y-75, ANGLE_CONTROL_CENTER_Y+75, -45, 45);
  //    txtRoll.setText(Float.toString(quadRollAngle));
  //    txtPitch.setText(Float.toString(quadPitchAngle));
  //    angleInControl = true;
  //  }
  //  else if (!mousePressed && angleInControl) {
  //    angleControlX = ANGLE_CONTROL_CENTER_X;
  //    angleControlY = ANGLE_CONTROL_CENTER_Y;
  //    quadRollAngle = 0;
  //    quadPitchAngle = 0;
  //    txtRoll.setText(Float.toString(quadRollAngle));
  //    txtPitch.setText(Float.toString(quadPitchAngle));
  //    angleInControl = false;
  //  }
  //  fill(100, 100);
  //  rect(ANGLE_CONTROL_CENTER_X, ANGLE_CONTROL_CENTER_Y, 150, 150);
  //  fill(0);
  //  rect(angleControlX, angleControlY, 20, 20);

  if (SERIAL_SPD == 115200  && millis() - saveDebugTime > 20) {
    debugData += myPort.readStringUntil('\n');
    saveDebugTime = millis();
  }
  
  //  Save recieved debug data
  if (SERIAL_SPD == 115200 && millis() - saveTimer > 5000) {
    saveDebugData(debugData);
    saveTimer = millis();
  }
  
  //  Send keep-alive
  if (millis() - keepAliveTimer > 1000) {
    keepAliveTimer = millis();
    println("Sending: keep-alive");
    sendUpdate(myPort, 'k', 0);
  }
  
  //  Request Debugging Information
  if (requestDebug && (millis() - sendTimer) > MIN_SEND_TIME) {
    sendTimer = millis();
    println("Requesting debugging information");
    sendUpdate(myPort, 'd', 0);
    delay(200);
    lblDebug.setText(myPort.readStringUntil('\n'));
    requestDebug = false;
    sendTimer = millis();
  }

  //  Send new throttle
  if (prevQuadThrottle != quadThrottle && (millis() - sendTimer) > MIN_SEND_TIME) {
    println("Sending throttle: " + quadThrottle);
    sendUpdate(myPort, 'c', quadThrottle);
    prevQuadThrottle = quadThrottle;
    sendTimer = millis();
  }

  //  Send new angle coeficient
  if (prevAngleCo != quadAngleCo && (millis() - sendTimer) > MIN_SEND_TIME) {
    println("Sending angle coeficient: " + quadAngleCo);
    sendUpdate(myPort, 'a', Float.floatToRawIntBits(quadAngleCo));
    prevAngleCo = quadAngleCo;
    sendTimer = millis();
  }

  //  Send new rate coeficient
  if (prevRateCo != quadRateCo && (millis() - sendTimer) > MIN_SEND_TIME) {
    println("Sending rate coeficient: " + quadRateCo);
    sendUpdate(myPort, 'g', Float.floatToRawIntBits(quadRateCo));
    prevRateCo = quadRateCo;
    sendTimer = millis();
  }

  //  Send new pitch angle
  if (prevPitchAngle != quadPitchAngle && (millis() - sendTimer) > MIN_SEND_TIME) {
    println("Sending pitch angle: " + (quadPitchAngle+trimPitch));
    sendUpdate(myPort, 'p', Float.floatToRawIntBits(quadPitchAngle+trimPitch));
    prevPitchAngle = quadPitchAngle;
    sendTimer = millis();
  }

  //  Send new roll angle
  if (prevRollAngle != quadRollAngle && (millis() - sendTimer) > MIN_SEND_TIME) {
    println("Sending roll angle: " + (quadRollAngle+trimRoll));
    sendUpdate(myPort, 'r', Float.floatToRawIntBits(quadRollAngle+trimRoll));
    prevRollAngle = quadRollAngle;
    sendTimer = millis();
  }

  if (joystickConnected) {
    sldThrottle.setValue(int(map(quadThrottle, 1000, 2000, 2000, 1000)));
    txtRoll.setText(Float.toString(quadRollAngle));
    txtPitch.setText(Float.toString(quadPitchAngle));
  }
}

void sendUpdate(Serial port, char code, int value) {

  boolean goodSend = false;
  while (!goodSend) {
    String checkforbad = "";
    myPort.clear();
    port.write('S');
    port.write(code);
    serialSendInt(port, value);
    port.write(abs(value%255));
    while (myPort.available() < 2); 
    checkforbad += (char) myPort.read();
    checkforbad += (char) myPort.read();
    if (checkforbad.equals("SG")) {
      goodSend = true;
    }
    else {
      println("resending...");
    }
  }
}

void serialSendInt(Serial port, int value) {
  port.write((value & 0xff000000) >> 24);
  port.write((value & 0x00ff0000) >> 16);
  port.write((value & 0x0000ff00) >> 8);
  port.write( value & 0x000000ff);
}

// Use this method to add additional statements
// to customise the GUI controls
void customGUI() {
  txtAngleCo.setText(Float.toString(quadAngleCo));
  txtRateCo.setText(Float.toString(quadRateCo));
}

void saveDebugData(String saveData) {
  String[] dataArray = split(saveData, '\n');
  saveStrings("data.dat", dataArray);
  println("Data Saved");
}

void keyPressed() {
  final int MAX_MOVEMENT = 20;
  if (key == CODED) {
    if (keyCode == UP) {
      quadPitchAngle = -1*MAX_MOVEMENT;
    }
    if (keyCode == LEFT) {
      quadRollAngle = -1*MAX_MOVEMENT;
    }
    if (keyCode == RIGHT) {
      quadRollAngle = MAX_MOVEMENT;
    }
    if (keyCode == DOWN) {
      quadPitchAngle = MAX_MOVEMENT;
    }
    txtRoll.setText(Float.toString(quadRollAngle));
    txtPitch.setText(Float.toString(quadPitchAngle));
  }
}

void keyReleased() {
  if (key == CODED) {
    if (keyCode == UP || keyCode == DOWN) {
      quadPitchAngle = 0;
    }
    if (keyCode == LEFT || keyCode == RIGHT) {
      quadRollAngle = 0;
    }
    txtRoll.setText(Float.toString(quadRollAngle));
    txtPitch.setText(Float.toString(quadPitchAngle));
  }
}
