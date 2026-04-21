/*
 * PWM.c
 *
 * Created: 14/04/2026 10:51:51
 *  Author: Usuario
 */ 

#include "PWM1.h"

// Inicialización del PWM en Timer1
void PWM1_init(void){
	
	// Configurar PB1 (OC1A / D9) como salida
	DDRB |= (1 << DDB1);
	
	// Modo Fast PWM con TOP en ICR1 (Modo 14)
	TCCR1A |= (1 << COM1A1); // Clear OC1A on compare match
	TCCR1A |= (1 << WGM11);
	
	TCCR1B |= (1 << WGM13) | (1 << WGM12);
	
	// Prescaler = 8
	TCCR1B |= (1 << CS11);
	
	// TOP para 20 ms (50 Hz)
	ICR1 = 19999;
	
	// Duty inicial (neutral ~1.5 ms)
	OCR1A = 1500;
}

// Cambiar duty cycle
void PWM1_setDuty(uint16_t duty){
	OCR1A = duty;
}