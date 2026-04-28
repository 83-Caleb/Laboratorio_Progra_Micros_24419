// Universidad Del Valle de Guatemala
// Ingeniería Mecatrónica
// Programación de microcontroladores
 // Ejercicio de clase
 // Caleb Portillo - 24419

/*****************************************************************************************************************************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <util/delay.h>

// Variables
    #define BAUD_RATE 9600
    #define UBRR_VALUE (F_CPU / (16UL * BAUD_RATE) - 1)

/*****************************************************************************************************************************************************/
// Function prototypes
int main(void); // Ciclo principal
void setup(); // Realiza todas las configuraciones
void init_UART();
void writeChar(char c);
void writeEEPROM(uint16_t direccion, uint8_t dato);
uint8_t readEEPROM(uint16_t direccion);

const char* L1_on = "L1:1";
const char* L1_off = "L1:0";
const char* L2_on = "L2:1";
const char* L2_off = "L2:0";
uint8_t num_cara = 0;

char* string_rec = "----"; // Apartamos 4 espacios para no caerle encima a nada

/*****************************************************************************************************************************************************/
// Main Function
int main(void){
	
	setup(); // Para realizar configuraciones
	init_UART(UBRR_VALUE);
	//sei(); // Para activar interrupciones globales	
	
	uint8_t lectura = readEEPROM(dir_EEPROM);


    while (lectora != 0xFF)
    {
		writeChar(lectura);
		writeEEPROM(dir_EEPROM)
		dir_EEPROM++;
		
    }
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	
	DDRD |= (1<<DDD6)|(1<<DDD5);
	PORTD &= ~((1<<PORTD6)|(PORTD5));
	
	DDRD
	PORTD
	PCICR
	PCMSK2
		
	// Reloj general
	//CLKPR = (1<<CLKPCE); // Enable del prescaler
	//CLKPR = (1<<CLKPS0); // Set del CLKPS2 (0000_0001), que divide entre 2 para trabajar a 8Mhz
	
	/*
	// Configuración del ADC, empieza el 6 activado
	ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2) | (1 << MUX1); // Configuracion de la referencia del ADC y justificado a la izquierda
	ADCSRA |= (1 << ADEN) | (1 << ADIE); // ADC Enable e Interrupt Enable
	ADCSRA |= (1 << ADPS2) | (1 << ADPS1); // Prescaler de 64 para el ADC
	ADCSRA |= (1 << ADSC); // Empieza primera conversión para ADC6
	*/
}

void writeChar(char c){
	while(!(UCSR0A & (1<<UDRE0)));
	UDR0 = c;
}

void estado_LEDs(){
	
}

ISR(USART_RX_vect){
	uint8_t rx_buffer = UDR0;
	
	if (rx_buffer != '\n'){
		writeChar(rx_buffer);
		
	}
	
	/* writeChar(rx_buffer);
	writeEEPROM(dir_EEPROM, `); */
	
	
}

void writeEEPROM(uint16_t direccion, uint8_t dato){
	// Esperar a que se termine de escribir el anterios
	while(EECR & (1 << EEPE)); // While dato
	
	EEAR = direccion; // Direccion
	EEDR = dato;
	
	EECR |= (1<<EEPE);

}

uint8_t readEEPROM(uint16_t direccion){
	while(EECR & (1 << EEPE)); // While dato
	EEAR = direccion; // Direccion
	// read enable
	return da
}

ISR(PCINT2_vect){
	uint8_t estado_PIND = PIND & (1<<PIND2);
	if(!(estado_PIND == (1<<PIND2))){
		^^
	}	
}