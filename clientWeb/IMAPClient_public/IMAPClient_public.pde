/*****************************************************/
/*  Email Checker                                    */
/*  Designer : Arturo Erbsman                        */
/*  Programmer : Antoine Villeret                    */
/*  ENSADLab - 2010                                     */
/*****************************************************/

#include <Ethernet.h>

#define LEDPIN 9 // LED connected to this pin
#define TTL 10000 // time to live : time before a command is considered to be lost

byte mac[] = {0x00, 0x1C, 0xC0, 0x5D, 0x5C, 0x26};

// IP settings
byte ip[] = { 
  172, 30, 34, 138 };
byte gateway[] = { 
  172, 30, 34, 254 };
byte subnet[] = { 
  255, 255, 255, 0 };

byte webmail[] = {212, 27, 48, 2}; // imap.free.fr
char user[] = "yourname"; // your user name
char pass[]="yourpass"; // your password
int i,length,command_id;
unsigned long time,iteration;
boolean message_flag;
char c;
char matchseq[] = "UNSEEN"; // char seq that indicates new messages
int matchseqlength;

Client client(webmail, 143);

int asknwait(int count, char* command, ...) // this function sends the command in char command to the server and waits for an answer
{

  command_id++;
  Serial.print("\nC:a");
  Serial.print(command_id);
  Serial.print(" ");

  client.print("a");
  client.print(command_id);
  client.print(" ");

  // handles severals char arg
  va_list l_Arg;
  va_start(l_Arg, count);

  while( count ) {
    Serial.print(command);
    client.print(command);
    count--;
    command =  va_arg(l_Arg, char*); 
  }  
  va_end(l_Arg);

  Serial.println();
  client.println();

  time = millis()+TTL;
  Serial.println("Wait... ");
  while(!client.available()){ // waiting for an answer from the server
    if (time < millis())
    {
      Serial.print("Time out. Close the connection.");
      client.stop();
      Serial.println(" Reset the connection");
      return -1;
    }
  }

  return 0;

}

void setup()
{
  Serial.begin(9600);
  // global variable initialization
  iteration = 0;
  c=0,i=0;
  int j,k;

  pinMode(LEDPIN,OUTPUT);

  matchseqlength = sizeof(matchseq)/sizeof(char)-1;
}

void loop()
{
  command_id=0;
  iteration++;

start:
  Serial.print("Iteration : ");
  Serial.println(iteration);

  // is client connected ?
  if (!client.connected()) {
    Serial.println();
    client.flush();
    client.stop();
    Serial.println("Reconnecting.");
    Ethernet.begin(mac, ip, gateway, subnet);
    if (client.connect()) {
      Serial.println("Connected.");
    } 
    else {
      Serial.println("Connection failed. Next try in 5 s.");
      delay(5000);
      goto start;
    }
  }

  client.flush();

  if(asknwait(4,"LOGIN ",user," ",pass)) goto start;
  client.flush();
  if(asknwait(1,"SELECT INBOX")) goto start;
  int j=0;
  while(client.available()>0)
  {
    c=client.read();
    Serial.print(c);
    if (c==matchseq[j]) {
      j++;
    }
    else {
      j=0;
    }
    if (j==matchseqlength) break;
  }
  digitalWrite(LEDPIN,j==matchseqlength);
  client.flush();
  asknwait(1,"LOGOUT");

  Serial.print("Fin iteration ");
  Serial.println(iteration);
  Serial.println("**********\n");
  delay(10000);
}
