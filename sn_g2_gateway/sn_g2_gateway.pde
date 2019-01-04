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

#include <Countdown.h>
#include <FP.h>
#include <MQTTFormat.h>
#include <MQTTLogging.h>
#include <MQTTPacket.h>
#include <MQTTPublish.h>
#include <MQTTSubscribe.h>
#include <MQTTUnsubscribe.h>

// define variable
uint8_t errorBee;
uint8_t errorWiFi;
unsigned long previous;
uint16_t socket_handle = 0;
uint8_t status;
char topicList[2][45];
unsigned char payloadList[2][100]={'\0'};


// choose socket (SELECT USER'S SOCKET)
///////////////////////////////////////
uint8_t socket = SOCKET1;
///////////////////////////////////////

// choose TCP server settings
///////////////////////////////////////
char HOST[]        = "192.168.1.54";//"mqtt.thingspeak.com";//"10.49.1.32"; //MQTT Broker
char REMOTE_PORT[] = "1883";  //MQTT
char LOCAL_PORT[]  = "3000";
///////////////////////////////////////
void connectMQTT(){
  if (status == true)
  {
    MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
    unsigned char buf[200];
    int buflen = sizeof(buf);

    // options
    data.clientID.cstring = (char*)"mt1";
    data.keepAliveInterval = 30;
    data.cleansession = 1;
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
      USB.println(F("3.2. Send data OK"));
    }
    else
    {
      USB.println(F("3.2. errorWiFi calling 'send' function"));
      WIFI_PRO.printErrorCode();
    }
  ////////////////////////////////////////////////
  // 3.4. close socket
  ////////////////////////////////////////////////
  errorWiFi = WIFI_PRO.closeSocket(socket_handle);

  // check response
  if (errorWiFi == 0)
  {
    USB.println(F("3.3. Close socket OK"));
  }
  else
  {
    USB.println(F("3.3. Error calling 'closeSocket' function"));
    WIFI_PRO.printErrorCode();
  }

  //////////////////////////////////////////////////
  // 4. Switch OFF
  //////////////////////////////////////////////////
  USB.println(F("WiFi switched OFF\n\n"));
  WIFI_PRO.OFF(socket);
}
void cleanPayload(){
  for(int i=0; i < 2; i++){
    for(int j=0; j <100;j++){
      payloadList[i][j]='\0';
    }
  }
}
void setup()
{  
  USB.ON();
  USB.println(F("Gateway"));
  xbee802.ON();
  if(!WIFI_PRO.ON(socket)){
      configureWiFi();
      connectMQTT();
  }
  strncpy(topicList[0], "g2/channels/648459/publish/44GWV2IQ8OU9Z7X3",44);
  strncpy(topicList[1], "g2/channels/666894/publish/J8J79SZWTMYLVK09",44);
}

void sendMessages(){
  for(int i=0; i<2; i++){
    if(strlen((char *)payloadList[i])>0){
      publish(topicList[i], payloadList[i]);
    }
  }
}

void loop()
{ 
  cleanPayload();
  // receive XBee packet (wait for 30 seconds)
  errorBee = xbee802.receivePacketTimeout( 30000 );

  // check answer  
  if( errorBee == 0 ) 
  {
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("---------- Data ----------"));  
    USB.println( xbee802._payload, xbee802._length);
    USB.print(F("---------- Length ----------"));  
    USB.println( xbee802._length,DEC);
    split();
    if(WIFI_PRO.isConnected()){
      sendMessages();
    }else{
      configureWiFi();
      connectMQTT();
      sendMessages();
    }
  }
  else
  {
    switch(errorBee){
      case 1:
        USB.println(F("ERROR: Timeout when receiving answer"));
      break;
      case 2:
        USB.println(F("ERROR: Frame Type is not valid"));
      break;
      case 3:
        USB.println(F("ERROR: Checksum byte is not available"));
      break;
      case 4:
        USB.println(F("ERROR: Checksum is not correct"));
      break;
      case 5:
        USB.println(F("ERROR: Error escaping character in checksum byte"));
      break;
      case 6:
        USB.println(F("ERROR: Error escaping character within payload bytes"));
      break;
      case 7:
        USB.println(F("ERROR: Buffer full. Not enough memory space"));
      break;
    }   
  }
}

void configureWiFi(){
  errorWiFi = WIFI_PRO.ON(socket);

  if ( errorWiFi == 0 )
  {
    USB.println(F("1. WiFi switched ON"));
  }
  else
  {
    USB.println(F("1. WiFi did not initialize correctly"));
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
    USB.print(F("2. WiFi is connected OK"));
    USB.print(F(" Time(ms):"));
    USB.println(millis() - previous);

    // get IP address
    errorWiFi = WIFI_PRO.getIP();

    if (errorWiFi == 0)
    {
      USB.print(F("IP address: "));
      USB.println( WIFI_PRO._ip );
    }
    else
    {
      USB.println(F("getIP errorWiFi"));
    }
  }
  else
  {
    USB.print(F("2. WiFi is connected ERROR"));
    USB.print(F(" Time(ms):"));
    USB.println(millis() - previous);
  }



  //////////////////////////////////////////////////
  // 3. TCP
  //////////////////////////////////////////////////

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

      USB.print(F("3.1. Open TCP socket OK in handle: "));
      USB.println(socket_handle, DEC);
    }
    else
    {
      USB.println(F("3.1. Error calling 'setTCPclient' function"));
      WIFI_PRO.printErrorCode();
      status = false;
    }
  }
}



void publish(char *topic, unsigned char *payload){
  if (status == true)
  {
    MQTTString topicString = MQTTString_initializer;
    unsigned char buf[200]={'\0'};
    int buflen = sizeof(buf);

    topicString.cstring = (char *)topic;

    USB.printf("\n---- %s %s ----\n",topicString.cstring, payload);
    
    int payloadlen = strlen((const char*)payload);

    int len = MQTTSerialize_publish(buf, buflen, 0, 0, 0, 0, topicString, payload, payloadlen); /* 2 */

    //len += MQTTSerialize_disconnect(buf + len, buflen - len); /* 3 */


    ////////////////////////////////////////////////
    // 3.2. send data
    ////////////////////////////////////////////////
    USB.println(F("Sending data"));
    errorWiFi = WIFI_PRO.send( socket_handle, buf, len);

    // check response
    if (errorWiFi == 0)
    {
      USB.println(F("3.2. Send data OK"));
    }
    else
    {
      USB.println(F("3.2. errorWiFi calling 'send' function"));
      WIFI_PRO.printErrorCode();
    }

    ////////////////////////////////////////////////
    // 3.3. Wait for answer from server
    ////////////////////////////////////////////////
    /*      USB.println(F("Listen to TCP socket:"));
          errorWiFi = WIFI_PRO.receive(socket_handle, 30000);

          // check answer
          if (errorWiFi == 0)
          {
            USB.println(F("\n========================================"));
            USB.print(F("Data: "));
            USB.println( WIFI_PRO._buffer, WIFI_PRO._length);

            USB.print(F("Length: "));
            USB.println( WIFI_PRO._length,DEC);
            USB.println(F("========================================"));
          }
    */
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
                addField(payloadList[0], inFrame[i+1], 5);
                addField(payloadList[0], inFrame[i+2], 6);
                addField(payloadList[0], inFrame[i+3], 7);
              break;
              case 1://TEMP
                addField(payloadList[0], inFrame[i+1], j);
              break;
              case 2://HUM
                addField(payloadList[0], inFrame[i+1], j);
              break;
              case 3://PRE
                addField(payloadList[0], inFrame[i+1], j);
              break;
              case 4://BAT
                addField(payloadList[0], inFrame[i+1], j);
                bat = atoi(inFrame[i+1]);
                if(bat < 20){
                  addField(payloadList[0], "3", 8);
                }
              break;
              case 5:
                if(strncmp(inFrame[i+1], "PIR",3)==0){
                  addField(payloadList[0], "1", 8);

                }else if(strncmp(inFrame[i+1], "FF",2)==0){
                  addField(payloadList[0], "2", 8);
                }
              break;   
            }
         }
      }
   }
}

void addField(unsigned char * payload, char * value, int field){
  unsigned char aux[20];
  if(strlen((char *)payload)>0){
    snprintf((char *)aux, 20, "&field%d=%s", field, value);
  }else{
    snprintf((char *)aux, 20, "field%d=%s", field, value);  
  }
  strcat((char *)payload, (char *)aux);
}

