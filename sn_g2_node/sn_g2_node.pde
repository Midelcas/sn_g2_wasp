/*
    ------ Waspmote Pro Code Example --------

    Explanation: This is the basic Code for Waspmote Pro

    Copyright (C) 2016 Libelium Comunicaciones Distribuidas S.L.
    http://www.libelium.com

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// Put your libraries here (#include ...)

#include <WaspSensorEvent_v30.h>
#include <WaspXBee802.h>
#include <WaspFrame.h>
const int NO_INTERRUPT = 0;
const int FF_INTERRUPT = 1;
const int PIR_INTERRUPT = 2;

uint8_t status;
int x_acc;
int y_acc;
int z_acc;
int bat;
uint8_t value = 0;
float temp;
float humd;
float pres;
// Destination MAC address
//////////////////////////////////////////
char RX_ADDRESS[] = "0013A200416BE2A0";
//////////////////////////////////////////
// Define the Waspmote ID
char WASPMOTE_ID[] = "g2_node";
// define variable
uint8_t error;
pirSensorClass pir(SOCKET_1);

void publish(int interrupt){ 
  xbee802.ON();
  frame.createFrame(ASCII);  
  if (!interrupt) {
    USB.print(F("\n-------------RTC--------------\n"));
    frame.addSensor(SENSOR_ACC, x_acc, y_acc, z_acc);
    frame.addSensor(SENSOR_TCA, temp);
    frame.addSensor(SENSOR_HUMA, humd);
    frame.addSensor(SENSOR_PA, pres);
    frame.addSensor(SENSOR_BAT, bat); 
  } else if (interrupt == PIR_INTERRUPT) {
    USB.print(F("\n-------------PIR--------------\n"));
    frame.addSensor(SENSOR_STR, "PIR");
  } else if (interrupt == FF_INTERRUPT) {
    USB.print(F("\n-------------FF--------------\n"));
    frame.addSensor(SENSOR_STR, "FF");
  }
  if((interrupt == PIR_INTERRUPT)||(interrupt == FF_INTERRUPT)){
    while((error = xbee802.send( RX_ADDRESS, frame.buffer, frame.length ))!=0){
      if(error== 0){
        break;
      }else{
        USB.println(F("send error"));
      
        // blink red LED
        Utils.blinkRedLED();
        delay(5000);
        USB.println(F("retrying")); 
      }
    }
  }else{
    for(int i=0; i<3; i++){
      error = xbee802.send( RX_ADDRESS, frame.buffer, frame.length );
      if(error ==0)
        break;
      else{
        delay(5000);
        USB.println(F("retrying"));
      }
    }
  }
  if( error == 0 )
  {
    USB.println(F("send ok"));
    
    // blink green LED
    Utils.blinkGreenLED();
    
  }else{
    USB.println(F("send error"));
      
      // blink red LED
      Utils.blinkRedLED();
  }
  xbee802.OFF();
}

void setup()
{

    // init USB port
  USB.ON();
  USB.println(F("node XBEE Setup"));
  
  // store Waspmote identifier in EEPROM memory
  frame.setID( WASPMOTE_ID );
  
  // init XBee
  xbee802.ON();

  // put your setup code here, to run once:
  USB.println(F("Sensors setup"));
  
  ACC.ON();
  USB.println(F("Init ACC"));
  
  ACC.setFF();
  USB.println("Free Fall interrupt configured");

  USB.println(F("Init RTC"));
  RTC.ON();       
  
  // Setting time
  RTC.setTime("12:07:18:04:13:35:00");
  USB.print(F("RTC was set to this time: "));
  USB.println(RTC.getTime());

  // Turn on the sensor board
  Events.ON();
  
  // Enable interruptions from the board
  Events.attachInt();

}

//interrupt -> 0, no interruption
//interrupt -> 1, FF interruption
//interrupt -> 2, PIR interruption



void loop()
{
  //-------------------------------
    
  // Reading time
  USB.print(F("Time [Day of week, YY/MM/DD, hh:mm:ss]: "));
  USB.println(RTC.getTime());
  
  // Sleep to Wake activation
  ACC.setSleepToWake();
  USB.println("Sleep to Wake mode configured");
  
  PWR.deepSleep("00:00:00:30", RTC_OFFSET, RTC_ALM1_MODE1, SENSOR_ON);

  USB.ON();
  USB.println(F("Waspmote wakes up"));
  if( intFlag & ACC_INT )
  {
    // unset the Sleep to Wake
    ACC.unsetFF();
    ACC.unSetSleepToWake();
    // read the acceleration source register
    delay(200);
    USB.println(F("++++++++++++++++++++++++++++++++++"));
    USB.println(F("++ Free Fall interrupt detected ++"));
    USB.println(F("++++++++++++++++++++++++++++++++++"));  
    // clear the accelerometer interrupt flag on the general interrupt vector
    intFlag &= ~(ACC_INT);  
    ACC.setFF();
    publish(FF_INTERRUPT);
  }
  //Check interruption RTC
  if( intFlag & RTC_INT ) {
    // clear interruption flag
    intFlag &= ~(RTC_INT);
    USB.println(F("-------------------------"));
    USB.println(F("RTC INT Captured"));
    USB.println(F("-------------------------"));
    status = ACC.check();
    //----------X Value-----------------------
    x_acc = ACC.getX();
    //----------Y Value-----------------------
    y_acc = ACC.getY();
    //----------Z Value-----------------------
    z_acc = ACC.getZ();
    //Temperature
    temp = Events.getTemperature();
    //Humidity
    humd = Events.getHumidity();
    //Pressure
    pres = Events.getPressure();
    bat = PWR.getBatteryLevel();
    publish(NO_INTERRUPT);
  } 
    // Cheak interruption from Sensor Board
  if (intFlag & SENS_INT)
  {
      USB.println(F("-----------------------------"));
      USB.println(F("Sensor INT"));
      USB.println(F("-----------------------------"));
    // Disable interruptions from the board
    Events.detachInt();
    
    // Load the interruption flag
    Events.loadInt();
    
    // In case the interruption came from PIR
    if (pir.getInt())
    {
      USB.println(F("-----------------------------"));
      USB.println(F("Interruption from PIR"));
      USB.println(F("-----------------------------"));
    }
    value = pir.readPirSensor();
    
    while (value == 1)
    {
      USB.println(F("...wait for PIR stabilization"));
      delay(1000);
      value = pir.readPirSensor();
    }
    // Clean the interruption flag
    intFlag &= ~(SENS_INT);
    publish(PIR_INTERRUPT);    
    // Enable interruptions from the board
    Events.attachInt();
  }
}
