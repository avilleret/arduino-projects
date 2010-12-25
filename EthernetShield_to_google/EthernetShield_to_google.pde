/*
        * A simple sketch that uses Ethernet Shield to send some values (via POST) to GoogleDocs
        * Based on code by RobertMParker for the WiShield <http://asynclabs.com/forums/viewtopic.php?f=16&t=489>
 */

#include <Ethernet.h>
#include <SPI.h>

#define DEBUG_PRINT // comment to disable Serial.print

long unsigned int time =0;

//Wireless configuration parameters ----------------------------------------
byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = {
  192,168,0,3};   // IP address of Ethernet Shield
byte gateway[] = {
  192,168,0,1};   // router or gateway IP address
byte subnet[]    = {
  255,255,255,0}; // subnet mask for the local network

// IP Address for spreadsheets.google.com
byte ipGoogle[] = {
  74,125,67,102};
char hostname[] = "spreadsheets.google.com";
char url[] = "/formResponse?formkey=<ENTER_YOUR_KEY_HERE>";



// create a client that connects to Google
Client clientGoogle(ipGoogle,80);

void setup()
{   
  // Enable Serial output and ask WiServer to generate log messages (optional)
#ifdef DEBUG_PRINT
  Serial.begin(115200);
#endif //DEBUG_PRINT
  Ethernet.begin(mac, ip, gateway, subnet);

  // give the Ethernet shield a second to initialize
  delay(1000);
  int time = millis();
  clientGoogle.connect();
}


void loop()
{
  float temperature = (float) random(1000)/10.; // create some random values to test
  float humidity = 45 + (millis()%1000)/100.;
  if ( millis() > time + 10000 && clientGoogle.connected()){ // update sheet each 10 s
    String feedData = "entry.0.single=" + String((int)temperature) + "," + String(int(temperature*100)%100) + "&entry.1.single=" + String(int(humidity)) + "," + String(int(humidity*100)%100) + "&pageNumber=0&backupCache=&submit=Envoyer";
    //Serial.println(feedData);
    postRequest(clientGoogle, ipGoogle, 80, hostname, url, feedData);
    time = millis();
  }
  delay(10);
}

void postRequest(Client client, byte *ip, unsigned int port, char *hostName, char *url, String feedData){ 
  String buf = "POST " + String(url) + " HTTP/1.1";

#ifdef DEBUG_PRINT 
  Serial.println(buf);
  Serial.println("Host: " + String(hostName));
  Serial.println("Content-Type: application/x-www-form-urlencoded");
  Serial.println("Content-Length: " + String(feedData.length()));
  Serial.println("");
  Serial.println(feedData);
  Serial.println("");
  Serial.println(""); 
#endif

  client.println(buf);
  client.println("Host: " + String(hostName));
  client.println("Content-Type: application/x-www-form-urlencoded");
  client.println("Content-Length: " + String(feedData.length()));
  client.println("");
  client.println(feedData);
  client.println("");
  client.println(""); // POST request as GET ends with 2 line breaks and carriage returns (\n\r);
}

