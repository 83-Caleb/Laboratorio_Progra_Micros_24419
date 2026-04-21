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
void writeChar(char c);
char readChar(void);
void displayASCII(char c);
/*****************************************************************************************************************************************************/
// Main Function
int main(void)
{
	setup();
	init_UART(UBRR_VALUE);

	while (1)
	{
		//writeChar('A');
		//_delay_ms(1000);
		
		char received = readChar(); // Creamos una variable tipo char y leemos UDR0
		displayASCII(received);
	}
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	// Configurar PORTB[5-0] como salidas
	DDRB |= 0x3F;
	PORTB &= 0x3F; // Empiezan apagados
	
	// Configurar PORTC[1-0] como salidas
	DDRB |= 0x03;	
	PORTB &= 0x03; // Empiezan apagados
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

void writeChar(char c)
{
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = c;
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