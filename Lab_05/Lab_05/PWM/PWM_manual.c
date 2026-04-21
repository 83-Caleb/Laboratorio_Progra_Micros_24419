/*
 * PWM_manual.c
 *
 * Created: 19/04/2026 14:49:38
 *  Author: Usuario
 */ 

#include <avr/io.h>
#include "PWM_manual.h"

// Inicialización del PWM manual (Timer0 - PB5 / D13)

void PWMm_init(void){
	// PB5 (D13) como salida
	DDRB |= (1 << DDB5);
	
	TCCR0A = 0;
	TCCR0B = 0;
	
	// Prescaler de 8
	TCCR0B |= (1 << CS01);

	// Enable de interrupciones por overflow
	TIMSK0 |= (1 << TOIE0);

    // Empezamos con PB apagado
	PORTB &= ~(1 << PB5);
}