/*
 * UART.c
 *
 * Created: 23/04/2026 14:36:31
 *  Author: Usuario
 */ 

void init_UART(uint16_t ubrr)
{
	// Configurar Baud Rate
	UBRR0 = ubrr;

	// Habilitar Rx y Tx
	UCSR0B = (1 << TXEN0) | (1 << RXEN0);

	// Modo async, sin paridad, 1 stop bit, 8 data bits
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}