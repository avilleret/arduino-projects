//
// Constance - A degenerating clock
// code by Antoine Villeret, Basile de Gaulle & ROmée de la Bigne - copyright 2010
// designed by Romée de la Bigne & Basile de Gaulle
//

/*
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

// définit les pin sur lesquels on branche les différents trucs
#define MIC_PIN 0 // analog input for mic
#define BT1_PIN 2 // digital input for button 1 (minus)
#define BT2_PIN 4 // digital input for button 2 (plus)
#define DATAOUT 11 //MOSI Master Ouput Slave Input - Arduino pin number
#define DATAIN 12 //MISO Master Input Slave Ouput - Arsuino pin number - not used, but part of builtin SPI
#define SPICLOCK 13 //sck clock
#define SLAVESELECT 10 //ss Slave Select - Arduino pin that should be connected to CS (Chip Select) pin on chip (pin 12 on MAX7219)
#define THRESPIN 1 // Analog in pour le potentiometre définissant le seuil (threshold)
#define CURVE_COEFF 0. // Curve coefficient
#define CURVE_SIZE 128 // table size for curve

#define UP_TIME 20 // temps de montée en ms
#define DOWN_TIME 20 // temps de descente en ms
#define WAIT_TIME 10 // temps d'attente en ms éteint
// le temps d'attente allumé est égal à 1000 - (UP_TIME + DOWN_TIME + WAIT_TIME)
//#define THRESHOLD 350 // seuil pour le déclenchement du bug...
#define RELEASE_BTN_TIME 200 // temps d'attente pour relacher les boutons

byte digit=1;
long time;
unsigned long compile_time = 0; // heure à laquelle a été compilé le sketch en seconde
unsigned long current_time; // temps a afficher avec le décalage
float coeff=1.; // coefficient de variation de la durée des secondes
long unsigned int count=0;
long unsigned int sum=0.;
unsigned int mic=0;
unsigned int threshold;
float curve[CURVE_SIZE];


///////////////////////////////////////////////////////////////////
//spi transfer function (from ATmega168 datasheet)
char spi_transfer(volatile char data)
{
  SPDR = data; // Start the transmission
  while (!(SPSR & (1<<SPIF))) // Wait the end of the transmission
  {
  };
  return SPDR; // return the received byte
}

///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////
byte write_7seg(int digAddress, int displayValue) //dig pot data transfer function
{
  digitalWrite(SLAVESELECT,LOW); //digital pot chip select is active low
  //2 byte data transfer to digital pot
  spi_transfer(digAddress);
  spi_transfer(displayValue);
  digitalWrite(SLAVESELECT,HIGH); //release chip, signal end transfer
}

///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////
void setup()
{
  byte i;
  byte clr;

  pinMode(BT1_PIN, INPUT);
  pinMode(BT2_PIN, INPUT);
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  pinMode(SLAVESELECT,OUTPUT);
  digitalWrite(SLAVESELECT,HIGH); //disable device
  unsigned long hour, minute, seconde;
  char tmp[2];

  //analogReference(EXTERNAL); // switch DAC reference to AREF pin
  
  ///////////////////////////////////////////////////////////////////
  // SPCR = 01010000
  //interrupt disabled,spi enabled,msb 1st,master,clk low when idle,
  //sample on leading edge of clk,system clock/4 (fastest)
  SPCR = (1<<SPE)|(1<<MSTR);
  clr=SPSR;
  clr=SPDR;
  delay(10);
  ///////////////////////////////////////////////////////////////////

  //clear 7221 and format to receive data
  write_7seg(0x0C,1);  // Set Shutdown register to Normal Operation Mode
  write_7seg(0x09,0xFF); // Set Decode-Mode Register to code B
  write_7seg(0x0B,0x05); // Set Scan limit register to use 6 digits

  Serial.begin(9600);
  // définit la variable compile_time qui donne l'heure de la compilation en milliseconde
  // __TIME__ est une constante qui est remplacée à la compilation par l'heure actuelle donc l'heure de la compilation 
  // c'est une chaine de caractère on peut donc accéder à chaque caractère avec l'opérateur []
  // tmp est une chaine de 2 caractères à laquelle on affecte successivement le nombre d'heure, minute et seconde
  // puis on transforme la chaine de caractère en integer avec la fonction atoi
  tmp[0] = __TIME__[0];
  tmp[1] = __TIME__[1];
  hour = atoi(tmp);
  tmp[0] = __TIME__[3];
  tmp[1] = __TIME__[4];
  minute = atoi(tmp);
  tmp[0] = __TIME__[6];
  tmp[1] = __TIME__[7];  
  seconde = atoi(tmp);
  compile_time = ( ( (hour * 60 + minute ) * 60 ) + seconde );
  Serial.println(compile_time);
  current_time = compile_time*1000 + millis();
  coeff = 1.;
  //threshold = analogRead(THRESPIN);
  threshold = 200;
  mic=0;
  Serial.print("threshold : ");
  Serial.print(threshold);
  makeCurve();
}

///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////
void loop()
{

  displayhour(current_time); 
  coeff *= 1.005;
  fading();
  current_time += 1000.; // on incrément d'une seconde
  current_time = current_time % 86400000; // on remet current à 0 dès qu'on atteint 24h pour éviter d'exploser la mémoire de l'Arduino
}

// Fonction   write_7seg(0x01,i); i étant le nomnbre a afficher (de 0 à 15)
// Fonction   write_7seg(0x0A,j); j étant l'intensité de l'afficheur

void displayhour(unsigned long t /*temps en ms a afficher*/){
  unsigned long time;
  int hour, minute, seconde;
  time = t/1000;
  seconde = time % 60;
  minute = ( time / 60) % 60;
  hour = ( time / 3600) % 24; 

/*
  Serial.print(hour);
  Serial.print("h");
  Serial.print(minute);
  Serial.print("m");
  Serial.print(seconde);
  Serial.print("s\t");
  Serial.print("decalage : ");
  Serial.print(compile_time*1000+millis()-t);
  Serial.print("ms\t");
*/

  write_7seg(0x05,seconde / 10);
  write_7seg(0x06,seconde % 10);
  write_7seg(0x03,minute / 10);
  write_7seg(0x04,minute % 10);
  write_7seg(0x01,hour / 10);
  write_7seg(0x02,hour % 10);
}

// fonction wait qu'on appelle dès qu'on entre dans une boucle
void wait(){

  unsigned int bt1, bt2, tmp;
  // on print toutes les valeurs qu'on peut, attention ça peut aller trop vite pour le Serial...

  tmp = analogRead(MIC_PIN) - tmp; // simple derivation
  long unsigned int delta;
  /*
   Serial.print("buttons :");
   Serial.print(bt1);
   Serial.println(bt2);
   */
   
   // ici on compare la différence du niveau sonore ambiant et du précédent au seuil de déclenchement
  if (tmp > threshold)
  {
    // si il y a du bruit on va très vite à l'heure actuelle
    Serial.println(tmp);
    Serial.println(mic);
    Serial.println("trop de bruit !!");
    // on force l'intensité à fond
    write_7seg(0x0A,15);
    coeff = 1.;
    do {
      current_time += 1000;
      delta = compile_time*1000+millis()-current_time;
      coeff = 500./delta;
/*
      Serial.print("delta :");
      Serial.println(delta);
      Serial.print("coeff");
      Serial.println(coeff);
*/

      displayhour(current_time);
      delay(float(1000*coeff));

    }
    while (coeff < 0.88);
    coeff = 1.;
  }

  mic = tmp;
  count++;
  sum += mic;
  
  reglage_de_l_heure();

}

void reglage_de_l_heure (){
  int btn1, btn2;

  btn1 = digitalRead(BT1_PIN);
  btn2 = digitalRead(BT2_PIN);

  if (btn1 && btn2){
    Serial.println(compile_time);
    displayhour(compile_time*1000+millis()); // ici on affiche l'heure mais attention, c'est mis à jour à chaque boucle et c'est peut etre un peu trop rapide pour le MAX
    write_7seg(0x0A,0x0F); // on met l'intensité à fond
    delay(1000); // on attend une seconde
    while ( 1 ){
      // tant qu'on n'appuie pas sur les boutons en meme temps on regle les heures

      // on lit l'état des boutons au début de la boucle
      btn1 = digitalRead(BT1_PIN);
      btn2 = digitalRead(BT2_PIN);
      Serial.println("We are setting the hour");

      if ( btn1 && !btn2 ) {
        // si on n'appuie que sur le premier bouton, on enlève une heure
        compile_time -= 3600;
      }
      else if ( !btn1 && btn2 ) {
        // si on n'appuie que sur le deuxieme bouton, on ajoute une heure
        compile_time += 3600;
      }
      else if ( btn1 && btn2 ) break; // si on appuie sur les 2 boutons en meme temps on sort de la boucle
      displayhour(compile_time*1000+millis());
      delay(RELEASE_BTN_TIME); // un petit delai le temps de relacher le bouton
    }
    delay(RELEASE_BTN_TIME); // un petit delai le temps de relacher les 2 boutons
    while ( 1 ){
      // tant qu'on n'appuie pas sur les 2 boutons en meme temps on regle les minutes

      // on lit l'état des boutons au début de la boucle
      btn1 = digitalRead(BT1_PIN);
      btn2 = digitalRead(BT2_PIN);
      Serial.println("We are setting the minute");
      if ( btn1 && !btn2 ) {
        // si on n'appuie que sur le premier bouton, on enlève une minute
        compile_time -= 60;
      }
      else if ( !btn1 && btn2 ) {
        // si on n'appuie que sur le deuxieme bouton, on ajoute une heure
        compile_time += 60;
      }
      else if ( btn1 && btn2 ) break; // si on appuie sur les 2 boutons en meme temps on sort de la boucle
      displayhour(compile_time*1000+millis());
      delay(RELEASE_BTN_TIME); // un petit delai le temps de relacher le bouton
    }
  }
}

void fading(){
  int i,j=0; // indice pour l'incrémentation de l'intensité
  long unsigned int t; //le temps
  // ici il faudrait changer la boucle do..while en while tout simple pour plus de lisibilité
  do { 
    t = millis();
    while ( millis() < t + UP_TIME * coeff) {
      wait();
    }
    write_7seg(0x0A,j); // on incrémente l'intensité de 0 à 15
    j++;
  } 
  while ( j < 15 ); // je ne suis pas sur qu'on atteigne l'intensité maximale... a vérifier

  // à cet endroit du code l'intensité est à fond
  while ( millis() < time + 1000 * coeff){
    wait();
  }; // attend jusqu'à ce qu'une seconde se soit écoulé depuis la dernière boucle
  time = millis();

  do { 
    t = millis();
    while (  millis() < t + DOWN_TIME * coeff) {
      wait();
    }
    write_7seg(0x0A,j); // on décrémente l'intensité jusqu'à 0
    j--;
  } 
  while ( j > 0);
  for ( i = 1; i < 7 ; i++ ) {
    // on éteint complètement l'affichage...
    write_7seg(i,0x0F);
  }

  t = millis();
  while ( millis() < t + WAIT_TIME) {
    // on attend 100 ms... les led sont à ce moment toutes éteintes
    wait();
  } 
}

void makeCurve(){
  int i;
  Serial.println("make curve...");
  for (i=0 ; i < CURVE_SIZE ; i++){
    curve[i] = (exp(float(i/(CURVE_SIZE-1)*CURVE_COEFF)-1))/(exp(CURVE_COEFF)-1);
    Serial.print(int(curve[i]));
    Serial.print(".");
    Serial.print(int(curve[i]*1000.)%1000);
    Serial.print("\t");
    Serial.println(curve[i]);
  }
  Serial.println("curve done.");
}
