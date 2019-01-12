/*  
 *  ------ [802_03] - receive XBee packets -------- 
 *  
 *  Explanation: This program shows how to receive packets with 
 *  XBee-802.15.4 modules.
 *  
 *  Copyright (C) 2016 Libelium Comunicaciones Distribuidas S.L. 
 *  http://www.libelium.com 
 *  
 *  This program is free software: you can redistribute it and/or modify 
 *  it under the terms of the GNU General Public License as published by 
 *  the Free Software Foundation, either version 3 of the License, or 
 *  (at your option) any later version. 
 *  
 *  This program is distributed in the hope that it will be useful, 
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of 
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 *  GNU General Public License for more details. 
 *  
 *  You should have received a copy of the GNU General Public License 
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>. 
 *  
 *  Version:           3.0
 *  Design:            David Gascón 
 *  Implementation:    Yuri Carmona
 */
 
#include <WaspXBee802.h>
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>
#include <WaspSensorEvent_v30.h>
#include <Countdown.h>
#include <FP.h>
#include <MQTTFormat.h>
#include <MQTTLogging.h>
#include <MQTTPacket.h>
#include <MQTTPublish.h>
#include <MQTTSubscribe.h>
#include <MQTTUnsubscribe.h>

#define TIMEOUT 5000.00
// define variable
uint8_t errorBee;
uint8_t errorWiFi;
unsigned long previous;
uint16_t socket_handle = 0;
uint8_t status;
char topicList[2][45];
unsigned char payloadList[2][100]={'\0'};
unsigned long timeout0=0;
unsigned long timeout1=0;
char cTimeOut[12]={'\0'};
unsigned long totalTime=TIMEOUT*5;
unsigned long waitTime=0;
// choose socket (SELECT USER'S SOCKET)
///////////////////////////////////////
uint8_t socket = SOCKET1;
///////////////////////////////////////

pirSensorClass pir(SOCKET_1);

// choose TCP server settings
///////////////////////////////////////
char HOST[]        = "138.100.48.251";//"192.168.1.54";//"mqtt.thingspeak.com";//; //MQTT Broker
char REMOTE_PORT[] = "1883";  //MQTT
char LOCAL_PORT[]  = "3000";
///////////////////////////////////////
void connectMQTT(){
  if (status == true)
  {
    MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
    MQTTPacket_willOptions will = MQTTPacket_willOptions_initializer;
    unsigned char buf[200];
    int buflen = sizeof(buf);

    // options
    will.retained = 0;
    will.qos=0;
    data.will = will;
    data.clientID.cstring = (char*)"mt1";
    data.keepAliveInterval = 30;
    data.cleansession = 1;
    data.willFlag = 0;
    int len = MQTTSerialize_connect(buf, buflen, &data);
    errorWiFi = WIFI_PRO.send( socket_handle, buf, len);
  }
}
void disconnectMQTT(){
  unsigned char buf[200];
  int buflen = sizeof(buf);
  int len = MQTTSerialize_disconnect(buf, buflen); /* 3 */

  errorWiFi = WIFI_PRO.send( socket_handle, buf, len);

    // check response
    if (errorWiFi == 0)
    {
      USB.println(F("\n\t\tSend data OK"));
    }
    else
    {
      USB.println(F("\n\t\tErrorWiFi calling 'send' function"));
      WIFI_PRO.printErrorCode();
    }
  ////////////////////////////////////////////////
  // 3.4. close socket
  ////////////////////////////////////////////////
  errorWiFi = WIFI_PRO.closeSocket(socket_handle);

  // check response
  if (errorWiFi == 0)
  {
    USB.println(F("\n\t\tClose socket OK"));
  }
  else
  {
    USB.println(F("\n\t\tError calling 'closeSocket' function"));
    WIFI_PRO.printErrorCode();
  }

  //////////////////////////////////////////////////
  // 4. Switch OFF
  //////////////////////////////////////////////////
  USB.println(F("\n\t\tWiFi switched OFF\n"));
  WIFI_PRO.OFF(socket);
}
void cleanPayload(){
  for(int i=0; i < 2; i++){
    for(int j=0; j <100;j++){
      payloadList[i][j]='\0';
    }
  }
}
void measure(){
  USB.println(F("\n\t-->MEASURING"));

  if(ACC.check()){
    //----------X Value-----------------------
    addIntField(payloadList[1], ACC.getX(), 5);
    //----------Y Value-----------------------
    addIntField(payloadList[1], ACC.getY(), 6);
    //----------Z Value-----------------------
    addIntField(payloadList[1], ACC.getZ(), 7);
  }
  //Temperature
  addFloatField(payloadList[1], Events.getTemperature(), 1);
  //Humidity
  addFloatField(payloadList[1], Events.getHumidity(), 2);
  //Pressure
  addFloatField(payloadList[1], Events.getPressure(), 3);
  //Battery
  addIntField(payloadList[1], PWR.getBatteryLevel(), 4);
  if(PWR.getBatteryLevel()<20){
    addIntField(payloadList[1], 3, 8);
  }
}
void configureWiFi(){
  errorWiFi=1;
  while((errorWiFi = WIFI_PRO.ON(socket))){
    if ( errorWiFi == 0 )
    {
      USB.println(F("\n\tWiFi switched ON"));
      break;
    }
    else
    {
      USB.println(F("\n\tWiFi did not initialize correctly"));
    }
  }

  

  //////////////////////////////////////////////////
  // 2. Check if connected
  //////////////////////////////////////////////////

  // get actual time
  previous = millis();

  // check connectivity
  while(!WIFI_PRO.isConnected()){
    delay(100);
    USB.print(".");
  }
  status=WIFI_PRO.isConnected();

  if ( status == true )
  {
    USB.print(F("\n\tWiFi is connected OK"));
    USB.print(F("\n\t Time(ms):"));
    USB.println(millis() - previous);

    // get IP address
    errorWiFi = WIFI_PRO.getIP();

    if (errorWiFi == 0)
    {
      USB.print(F("\n\tIP address: "));
      USB.println( WIFI_PRO._ip );
    }
    else
    {
      USB.println(F("\n\tgetIP errorWiFi"));
    }
  }
  else
  {
    USB.print(F("\n\tWiFi is connected ERROR ---"));
    USB.print(F("\n\tTime(ms):"));
    USB.println(millis() - previous);
  }

  // Check if module is connected
  if (status == true)
  {
    ////////////////////////////////////////////////
    // 3.1. Open TCP socket
    ////////////////////////////////////////////////
    errorWiFi = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);

    // check response
    if (errorWiFi == 0)
    {
      // get socket handle (from 0 to 9)
      socket_handle = WIFI_PRO._socket_handle;

      USB.print(F("\n\tOpen TCP socket OK in handle: "));
      USB.println(socket_handle, DEC);
    }
    else
    {
      USB.println(F("\n\tError calling 'setTCPclient' function"));
      WIFI_PRO.printErrorCode();
      status = false;
    }
  }
}
void sendMessages(){
  if(!WIFI_PRO.isConnected()){
    configureWiFi();
    connectMQTT();
  }
  for(int i=0; i<2; i++){
    if(strlen((char *)payloadList[i])>0){
      publish(topicList[i], payloadList[i]);
    }
  }
  //disconnectMQTT();
  cleanPayload();
}
void publish(char *topic, unsigned char *payload){
  if (status == true)
  {
    MQTTString topicString = MQTTString_initializer;
    unsigned char buf[200]={'\0'};
    int buflen = sizeof(buf);

    topicString.cstring = (char *)topic;

    USB.print(F("\n\t\tTOPIC "));
    USB.println(topicString.cstring);
    USB.print(F("\n\t\tPAYLOAD "));
    USB.println((char *)payload);
    
    int payloadlen = strlen((const char*)payload);

    int len = MQTTSerialize_publish(buf, buflen, 0, 0, 0, 0, topicString, payload, payloadlen); /* 2 */

    
    USB.println(F("\n\t\tSending Data"));
    
    
    for(int i=0; i<3;i++){
      errorWiFi=WIFI_PRO.send( socket_handle, buf, len)!=0;
      if (errorWiFi == 0){
        USB.println(F("\n\t\tSend data OK      "));
        break;
      }else{
        USB.println(F("\n\t\tErrorWiFi calling 'send' function"));
        WIFI_PRO.printErrorCode();
        delay(2000);
        USB.println(F("\n\t\tRetrying"));
      }
    }
  }
}
void split(){
  char str[100];
  const char s[2] = "#";
  char *token;
  char lookuptable[6][4]={"ACC", "NO", "ETO", "H2", "BAT", "STR"};
  uint8_t row=0;
  /*char topic[]= "g2/channels/648459/publish/44GWV2IQ8OU9Z7X3";
  unsigned char payload[100]="";*/
  char inFrame[16][17];//payload is divided into significant values
  
  snprintf((char *)str, 100, "%s", xbee802._payload);

  for(int i=0; i < 16; i++){
    for(int j=0; j <17;j++){ 
      inFrame[i][j]='\0';
    }
  }

  token=strtok(str,s);
   
   int a;
   while( token != NULL ) {
    a=0;
    for(int i=0; i < strlen(token); i++){
      if((token[i]!=':')&&(token[i]!=';')){//for every token, find special characters 
        inFrame[row][a]=token[i];
        a++;
      }else{
        a=0;
        row++;
      }
   }
   row++;
    token = strtok(NULL, s);
   }

   int bat=0;
   for(int i=0; i < 16; i++){
      for(int j=0; j < 6; j++){
         if(strncmp(inFrame[i], lookuptable[j],3)==0){
            switch(j){
              case 0://ACC
                addStrField(payloadList[0], inFrame[i+1], 5);
                addStrField(payloadList[0], inFrame[i+2], 6);
                addStrField(payloadList[0], inFrame[i+3], 7);
              break;
              case 1://TEMP
                addStrField(payloadList[0], inFrame[i+1], j);
              break;
              case 2://HUM
                addStrField(payloadList[0], inFrame[i+1], j);
              break;
              case 3://PRE
                addStrField(payloadList[0], inFrame[i+1], j);
              break;
              case 4://BAT
                addStrField(payloadList[0], inFrame[i+1], j);
                bat = atoi(inFrame[i+1]);
                if(bat < 20){
                  addStrField(payloadList[0], "3", 8);
                }
              break;
              case 5:
                if(strncmp(inFrame[i+1], "PIR",3)==0){
                  addStrField(payloadList[0], "1", 8);

                }else if(strncmp(inFrame[i+1], "FF",2)==0){
                  addStrField(payloadList[0], "2", 8);
                }
              break;   
            }
         }
      }
   }
}
void addStrField(unsigned char * payload, char * value, int field){
  unsigned char aux[18]={'\0'};
  if(strlen((char *)payload)>0){
    snprintf((char *)aux, 20, "&field%d=%s", field, value);
  }else{
    snprintf((char *)aux, 20, "field%d=%s", field, value);  
  }
  strcat((char *)payload, (char *)aux);
}
void addIntField(unsigned char * payload, int value, int field){
  unsigned char aux[18]={'\0'};
  if(strlen((char *)payload)>0){
    snprintf((char *)aux, 20, "&field%d=%d", field, value);
  }else{
    snprintf((char *)aux, 20, "field%d=%d", field, value);  
  }
  strcat((char *)payload, (char *)aux);
}
void addFloatField(unsigned char * payload, float value, int field){
  unsigned char aux[18]={'\0'};
  char valueStr[6]={'\0'};
  dtostrf(value, 2, 3, valueStr);
  if(strlen((char *)payload)>0){
    snprintf((char *)aux, 20, "&field%d=%s", field, valueStr);
  }else{
    snprintf((char *)aux, 20, "field%d=%s", field, valueStr);  
  }
  strcat((char *)payload, (char *)aux);
}
void waitXbeeMessage(uint32_t offset){
  xbee802.ON();
  timeout0=millis();
  errorBee = xbee802.receivePacketTimeout( offset );
  timeout1=millis();
  // check answer  
  if( errorBee == 0 ) {
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("\n\tNew Message"));  
    USB.println( xbee802._payload, xbee802._length);
    split();
  }else{
    switch(errorBee){
      case 1:
        USB.println(F("\n\tERROR: Timeout when receiving answer"));
      break;
      case 2:
        USB.println(F("\n\tERROR: Frame Type is not valid"));
      break;
      case 3:
        USB.println(F("\n\tERROR: Checksum byte is not available"));
      break;
      case 4:
        USB.println(F("\n\tERROR: Checksum is not correct"));
      break;
      case 5:
        USB.println(F("\n\tERROR: Error escaping character in checksum byte"));
      break;
      case 6:
        USB.println(F("\n\tERROR: Error escaping character within payload bytes"));
      break;
      case 7:
        USB.println(F("\n\tERROR: Buffer full. Not enough memory space"));
      break;
    }
    
  }
}

void setup(){  
  USB.ON();
  USB.println(F("\nInitializing Gateway"));
  
  ACC.ON();
  USB.println(F("\nInitializing ACC"));
  
  ACC.setFF();
  USB.println(F("\nFree Fall interrupt ON"));

  // Turn on the sensor board
  Events.ON();
  
  strncpy(topicList[0], "g2/channels/648459/publish/44GWV2IQ8OU9Z7X3",44);
  strncpy(topicList[1], "g2/channels/666894/publish/J8J79SZWTMYLVK09",44);
  configureWiFi();
  connectMQTT();
  waitTime = TIMEOUT;
}

void loop()
{ 
  // receive XBee packet (wait for 30 seconds)
  USB.println(F("\nWaiting ZigBee Message"));
  waitXbeeMessage(waitTime);
  
  if( intFlag & ACC_INT )
  {
    // unset the Sleep to Wake
    ACC.unsetFF();
    USB.println(F("\n\t-->FreeFall interrupt detected")); 
    addIntField(payloadList[1], 2, 8);
    clearIntFlag(); 
    ACC.setFF();
    sendMessages();
  }
  
  if(pir.readPirSensor()){
    USB.println(F("\n\t-->PIR interrupt detected"));
    if(strlen((char *)payloadList[1])==0){
      addIntField(payloadList[1], 1, 8); 
    }
    sendMessages();
  }
  
  if((timeout1-timeout0)>totalTime){
    totalTime=0;
  }else{
    totalTime-=(timeout1-timeout0);
  }

  if(totalTime==0){
    measure();
    sendMessages();
    totalTime=5*TIMEOUT;  
  }
  
  if(totalTime/TIMEOUT>0){
    waitTime=TIMEOUT;
  }else{
    waitTime=totalTime;
  }

  PWR.clearInterruptionPin();
}
