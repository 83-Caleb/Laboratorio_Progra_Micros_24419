// Universidad Del Valle de Guatemala
// Ingeniería Mecatrónica
// Programación de microcontroladores
// Laboratorio #4
// Caleb Portillo - 24419
/*****************************************************************************************************************************************************/
// Encabezado (Libraries)
#define F_CPU 16000000UL

#include <avr/io.h>
#include <util/delay.h>

// Variables
#define BAUD_RATE   9600
#define UBRR_VALUE  (F_CPU / (16UL * BAUD_RATE) - 1)
/*****************************************************************************************************************************************************/
// Function prototypes
int  main(void);
void setup();
void init_UART(uint16_t ubrr);
void init_ADC(void);
void writeChar(char c);
void writeString(char* string);
char readChar(void);
uint16_t read_ADC(uint8_t channel);
void displayASCII(char c);
/*****************************************************************************************************************************************************/
// Main Function
int main(void)
{
	setup();
	init_UART(UBRR_VALUE);
	init_ADC();
	
	while(1){
		writeString("\n ¿Qué desea hacer? \n");
		writeString("1 - Enviar caracter \n");
		writeString("2 - Leer potenciómetro \n");
		
		char option = readChar(); // Creamos una variable tipo char y leemos UDR0
		writeChar(option); // Eco del caracter recibido
		
		if (option == '1'){ // Enviar caracter
			writeString("\n Ingrese caracter:");
			char received = readChar(); // Leemos UDR0
			writeChar(received);
			displayASCII(received); // Mostrar en LEDs			
		}
		
		else if(option == '2') { // Leer potenciómetro
	        uint16_t lectura_ADC = read_ADC(7); // Lectura de ADCH
		    displayASCII(lectura_ADC); // Mostrar en LEDs
			writeString("\nValor ADC: ");
		}
		
		else { // No se seleccionó opción válida
			writeString("Seleccione una opción inválida");
		}
				
	}
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	// Configurar PORTB[5-0] como salidas
	DDRB |= 0x3F;
	PORTB &= 0x3F; // Empiezan apagados
	
	// Configurar PORTC[1-0] como salidas
	DDRC |= 0x03;
	PORTC &= 0x03; // Empiezan apagados
}

void init_UART(uint16_t ubrr)
{
	// Configurar Baud Rate
	UBRR0 = ubrr;
	// Habilitar Rx y Tx
	UCSR0B = (1 << TXEN0) | (1 << RXEN0);
	// Modo async, sin paridad, 1 stop bit, 8 data bits
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

void init_ADC(void)
{
	ADMUX = (1 << REFS0); // Referencia
	ADCSRA = (1 << ADEN)  // Enable ADC
	| (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // Prescaler 128
}

uint16_t read_ADC(uint8_t channel)
{
	ADMUX = (ADMUX & 0xF0) | (channel & 0x0F); // Seleccionar canal de ADC
	ADMUX |= (1 << ADLAR); // Justificado a la izquierda
	ADCSRA |= (1 << ADSC); // Iniciar la primera conversión
	while (ADCSRA & (1 << ADSC)); // Espera a que termine
	return ADCH; // Resultado de 10 bits, pero solo tomamos los 8 más significativos
}

void writeChar(char c)
{
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = c;
}

void writeString(char* string){
	
	for(uint8_t i = 0; string[i] != '\0'; i++){
		writeChar(string[i]);
	}
}

char readChar(void)
{
	// Espera hasta que haya un dato recibido (RXC0 = 1)
	while (!(UCSR0A & (1 << RXC0)));
	return UDR0;
}

void displayASCII(char c)
{
	// Asignar PORTB[5:0]
	PORTB = c;

	// Los bits [7:6] de c son PORTC[1:0]
	PORTC = (PORTC & 0xFC) | ((c >> 6) & 0x03);
}