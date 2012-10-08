const int dataIn = 4;
const int dataOut = 5;
const int taosClock = 6;
unsigned int theArray1[51];
unsigned int theArray2[51];



void setup() {
  unsigned int gain = 0;
  unsigned int offset = 0;

  pinMode(taosClock, OUTPUT);
  pinMode(dataOut, OUTPUT);
  pinMode(dataIn, INPUT);
  digitalWrite(taosClock, LOW);
  initializeTaos();
  delay(2);
  setGains(gain);
  setOffsets(offset);
  Serial.begin(9600);
  Serial.println("START!");
}

void loop() {
  int count;
  int exposureTime = 1;
  
  capture(exposureTime);
  Serial.println("------BEGIN NEW DATA------");
  for(count = 0; count < 51; count++)
  {
    Serial.println(theArray1[count]);
  }
  for(count = 0; count < 51; count++)
  {
    Serial.println(theArray2[count]);
  }
  delay(20);
}

void setOffsets(unsigned int theOffset) {
  sendByteTaos(0x40);
  sendByteTaos(theOffset);
  sendByteTaos(0x42);
  sendByteTaos(theOffset);
  sendByteTaos(0x44);
  sendByteTaos(theOffset);
}

void setGains(unsigned int theGain) {
  sendByteTaos(0x41);
  sendByteTaos(theGain);
  sendByteTaos(0x43);
  sendByteTaos(theGain);
  sendByteTaos(0x45);
  sendByteTaos(theGain);
}

void capture(int integrationTime) {
  int count;
  sendByteTaos(0x08);
  sendXclocks(22);

  delayMicroseconds(integrationTime);
  
  sendByteTaos(0x10);
  sendXclocks(5);
  sendByteTaos(0x02);

  while(digitalRead(dataIn) == HIGH)
  {
    digitalWrite(taosClock, HIGH);
    digitalWrite(taosClock, LOW);
  }

  for(count=0; count < 51; count++)
  {
    theArray1[count] = readByteTaos();
  }
  for(count = 0; count < 51; count++)
  {
    theArray2[count] = readByteTaos();
  }
}

void sendXclocks(int numberOfClockCycles) {
  int count;

  for(count = 0; count < numberOfClockCycles; count++)
  {
    digitalWrite(taosClock, HIGH);
    digitalWrite(taosClock, LOW);
  }
}

void initializeTaos() {
  digitalWrite(taosClock, LOW);
  digitalWrite(dataOut, LOW);
  sendXclocks(30);
  digitalWrite(dataOut, HIGH);
  sendXclocks(10);
  sendByteTaos(0x1b);
  sendXclocks(5);
  sendByteTaos(0x5f);
  sendByteTaos(0x00);
}

void sendByteTaos(unsigned int theData) {
  int count;

  digitalWrite(dataOut, LOW);

  digitalWrite(taosClock, HIGH);
  digitalWrite(taosClock, LOW);

  shiftOut(dataOut, taosClock, LSBFIRST, theData);

  digitalWrite(dataOut, HIGH);

  digitalWrite(taosClock, HIGH);
  digitalWrite(taosClock, LOW);
}

unsigned int readByteTaos() {
  unsigned int theData = 0x00;
  int count;

  //digitalWrite(taosClock, HIGH);
  //digitalWrite(taosClock, LOW);

  theData = shiftIn(dataIn, taosClock, LSBFIRST);
  for(count = 0; count < 8; count++)
  /*{
    digitalWrite(taosClock, HIGH);
    digitalWrite(taosClock, LOW);
    theData << 1;
    if(digitalRead(dataIn) == HIGH)
    {
      theData |= 0x01;
    }
    else
    {
      theData &= 0xfe;
    }
  }*/

  digitalWrite(taosClock, HIGH);
  digitalWrite(taosClock, LOW);
  digitalWrite(taosClock, HIGH);
  digitalWrite(taosClock, LOW);

  return theData;
}

