/*
 * NombreProgra.c
 *
 * Created: 
 * Author: 
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>

/****************************************/
// Function prototypes
void main();
void initADC();

/****************************************/
// Main Function
int main*(void)
{
	cli();
	setup();
	initADC();
	ADCSRA |= (1<<ADIE);
	ADCSRA |= (1<<ADSC);
	sei();
	while(1)
	{
	
	}
}

/****************************************/
// NON-Interrupt subroutines

void setup()
{
	// CLK a 1MHz
	CLKPR (1<<CLKPCE);
	CLKPR (1<<CLKPS2);
	// Salidas
	DDRD = 0xFF;
	PORTD = 0x00;
	
}

void initADC()
{
	ADMUX = 0;
	// Vref =AVcc, justificado a la izquierda
	ADMUX |= (1<<REFS0) | (1<<ADLAR) | (1<<MUX2) | (1<<MUX1);
	
	ADCSRA = 0;
	ADCSRA |= (1<<ADEN) | (1<<ADPS1) | (1<<ADPS0);
}

/****************************************/
// Interrupt routines

ISR(ADC_vect)
{
	PORTD = ADCH;
	ADCSRA |= (1<<ADSC);
}

ISR(TIMER1_OVF_VECT)
{
	TCNT1 
}
}