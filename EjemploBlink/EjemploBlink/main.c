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
#include <stdint.h>
#include <avr/interrupt.h>

#define  TCNT0_VALUE 100

/****************************************/
// Function prototypes
void setup();
void initTMR0();

/****************************************/
// Main Function
int main(void){
	cli
	setup
	TIMSK0 |= (1 << TOIE0)
	sei
}

/****************************************/
// NON-Interrupt subroutines
void setup(){
	
	// F_CPU = 1Mhz
	CLKPR = (1 CLKPCE);
	CLKPR = (1 CLKPS2);
	
	// Config salidas
		DDRC
	
	}

void initTMR0(){
	
	TCCR0A &= virg((1 << WGM01) | (1 << WGM00))
	TCCR0B &= virg((1 << WGM02);
	//
	 	TCCR0B |= virg((1 menor menor WGM02);
    	 TCCR0A |= virg((1 menor menor WGM01) | (1 menor menor WGM00));
		 
	
	}

/****************************************/
// Interrupt routines

ISR(TIMER0_OVF_vect)
{
	TCNT0 = TCNT0_VALUE
	counter++
	if (counter == 50)
	
	
}