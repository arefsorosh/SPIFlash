import processing.serial.*;
Serial myPort; //creates a software serial port on which you will listen to Arduino
Table dataTable; //table where we will read in and store values. You can name it something more creative!

char answer;
boolean pageTransmitError = false;
boolean headerTransmitError = false;
boolean initError = false;

String[] header;
int numReadings = 500; //keeps track of how many readings you'd like to take before writing the file. 
int readingCounter = 0; //counts each reading to compare to numReadings.
int pageCounter = 0;
int rowCounter = 0;
int headerLength;
int pageLength;
int random;
int headerHash; //checks for proper transmission of header data
int pageHash;  //checks for proper transmission of page data
byte status;

int handshake = 0x4F;
int complete = 0x5F;
int ack = 0x8C;
int pageAck = 0x7C;
int headerAck = 0x6C;
int readDataToCSV = 0xCC;
int errorCode = 0x00;
int initFail = 0x01;
int badTransmit = 0x02;

String fileName;
PFont fnt;                      // for font
int num_ports;
boolean device_detected = false;
String[] port_list;
String detected_port = "";

void setup() {
  size(400, 400);                         // size of application window
  background(0);                          // black background
  fnt = createFont("Arial", 16, true);    // font displayed in window
  
  random = int(random(0, 1073741823));         //create a random number for hash

  println(Serial.list());
  num_ports = Serial.list().length;      // get the number of detected serial ports
  port_list = new String[num_ports];     // save the current list of serial ports

  for (int i = 0; i < num_ports; i++) {
    port_list[i] = Serial.list()[i];
  }
}

void draw()
{
  background(0);
  // display instructions to user
  textFont(fnt, 14);
  text("1. Arduino or serial device must be unplugged.", 20, 30);
  text("   (unplug device and restart this application if not)", 20, 50);
  text("2. Plug the Arduino or serial device into a USB port.", 20, 80);

  // see if Arduino or serial device was plugged in
  if ((Serial.list().length > num_ports) && !device_detected) {
    device_detected = true;
    // determine which port the device was plugged into
    boolean str_match = false;
    if (num_ports == 0) {
      detected_port = Serial.list()[0];
    } else {
      for (int i = 0; i < Serial.list ().length; i++) {  // go through the current port list
        for (int j = 0; j < num_ports; j++) {             // go through the saved port list
          if (Serial.list()[i].equals(port_list[j])) {
            break;
          }
          if (j == (num_ports - 1)) {
            str_match = true;
            detected_port = Serial.list()[i];
          }
        }
      }
    }
  }
  // calculate and display serial port name
  if (device_detected) {
    text("Device detected:", 20, 110);
    textFont(fnt, 18);
    text(detected_port, 20, 150);
    textFont(fnt, 14);
    text("Would you like to connect? (Y/N)", 20, 180);
    if (answer == 'y') {
      text("Connecting to Arduino on port: ", 20, 210);
      textFont(fnt, 18);
      text(detected_port, 55, 210);
      myPort = new Serial(this, detected_port, 38400); //set up your port to listen to the serial port
      myPort.write (handshake);
    } else if (answer == 'n') {
      text("You can now safely unplug the Arduino", 20, 210);
    } else {
      text("Waiting for command....", 20, 210);
    }
    text("Current status: ", 20, 240);
    switch (status) {
    case '1':
      text("Waiting to connect", 40, 240);
      break;
    case '2':
      text("Reading data", 40, 240);
      text(pageCounter, 20, 270);
      text(" pages read", 30, 270);
      break;
    case '3':
      text("Saving data to file", 40, 240);
      text(fileName, 20, 270);
      break;
    case '4':
      text("Saved data to file", 40, 240);
      text(fileName, 20, 270);
      text("Safe to disconnect", 20, 270);
      break;
    }
  }
}

void getHeader() {
  while (myPort.available () > 0) {
    String head = myPort.readStringUntil('\n'); //The newline separator separates each Arduino loop. We will parse the data by each newline separator. 
    if (head!= null) { //We have a reading! Record it.
      head = trim(head); //gets rid of any whitespace or Unicode nonbreakable space
      println(head); //Optional, useful for debugging. If you see this, you know data is being sent. Delete if  you like. 
      header = split(head, ',');
      headerLength = header.length;
      if (headerTransmitError) {
        for (int i = (headerLength - 1); i >= 0; i--) {
          dataTable.removeColumn(i);
        }
        headerTransmitError = !headerTransmitError;
      }
      dataTable.addColumn("id"); //This column stores a unique identifier for each record. We will just count up from 0 - so your first reading will be ID 0, your second will be ID 1, etc. 
      for (int i = 0; i <= headerLength; i++) {
        dataTable.addColumn(header[i]);
      }
      int[] _header = int(split(head, ','));
      headerHash = hash(_header);
    }
  }
  myPort.write(headerAck);
}

void getDataToCSV() {
  while (myPort.available () > 0) {
    String val = myPort.readStringUntil('\n'); //The newline separator separates each Arduino loop. We will parse the data by each newline separator. 
    if (val!= null) { //We have a reading! Record it.
      val = trim(val); //gets rid of any whitespace or Unicode nonbreakable space
      println(val); //Optional, useful for debugging. If you see this, you know data is being sent. Delete if  you like. 
      float page[] = float(split(val, ',')); //parses the packet from Arduino and places the values into the sensorVals array. I am assuming floats. Change the data type to match the datatype coming from Arduino. 
      pageLength = page.length;
      if (pageTransmitError) {
        dataTable.removeRow(rowCounter-1);
        pageTransmitError = !pageTransmitError;
      }
      TableRow newRow = dataTable.addRow(); //add a row for this new reading
      newRow.setInt("id", dataTable.lastRowIndex());//record a unique identifier (the row's index)

      for (int i = 0; i <= pageLength; ++i)
      {
        newRow.setFloat(header[i], page[i]);
      }
      int[] _page = int(split(val, ','));
      pageHash = hash(_page);
    }
  }
  myPort.write(pageAck);
  pageCounter++;
}

void serialEvent(Serial myPort) {
  int _ackType = myPort.read();
  int _hash = myPort.read();

  if (_ackType == handshake) {
    if (_hash == 0) {
      myPort.write(readDataToCSV);
      getHeader();
    } else
      errorCode = initFail;
    myPort.write(errorCode);
    initError = !initError;
  } else if (_ackType == headerAck)
  {
    if (_hash == headerHash) {
      getDataToCSV();
    } else
      errorCode = badTransmit;
    myPort.write(errorCode);
    headerTransmitError = !headerTransmitError;
  } else if (_ackType == pageAck)
  {
    if (_hash == pageHash) {
      myPort.write(pageAck);
    } else
      errorCode = badTransmit;
    myPort.write(errorCode);
    pageTransmitError = !pageTransmitError;
  } else if (_ackType == complete)
  {
    if (_hash == pageHash) {
      fileName = str(year()) + str(month()) + str(day()) + str(dataTable.lastRowIndex())+".csv"; //this filename is of the form year+month+day+readingCounter
      saveTable(dataTable, fileName); //Woo! save it to your computer. It is ready for all your spreadsheet dreams.
    } else
      errorCode = badTransmit;
  }
}

void keyPressed() {
  answer = key;
}

int hash(int arrayName[]) {
  int midvalue;
  int arraySize = arrayName.length;
  if(arraySize%2 == 0) //Check if odd or even
{
  midvalue = arraySize/2;
}
else
{
  midvalue = (arraySize+1)/2;
}
int finalVal = arrayName[0]+arrayName[midvalue];
finalVal *= arrayName[arraySize-1];
finalVal = finalVal << 24;
finalVal = finalVal | random;
return finalVal;
}
