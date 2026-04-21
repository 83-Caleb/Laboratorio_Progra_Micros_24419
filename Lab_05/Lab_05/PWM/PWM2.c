/*
 * PWM2.c
 *
 * Created: 15/04/2026 08:54:55
 *  Author: Usuario
 */ 

#include "PWM2.h"

// Inicialización del PWM en Timer1
void PWM2_init(void){
	
	// Configurar PD3 (OC2B / D3) como salida
	DDRD |= (1 << DDD3);
	
	// Modo Fast PWM con TOP en OCRA (Modo 7)
	TCCR2A |= (1 << WGM21) | (1 << WGM20);
	TCCR2B |= (1 << WGM22);
	
	// Clear OC2B en compare match (config duty cycle no invertido)
	TCCR2A |= (1 << COM2B1);
	
	// Prescaler = 1024
	TCCR2B |= (1 << CS22) | (1 << CS21) | (1 << CS20);
	
	// Config periodo 20ms
	OCR2A = 155;
	
	// Duty inicial (neutro ~1.5 ms)
    OCR2B = 12;
}

// Cambiar duty cycle
void PWM2_setDuty(uint16_t duty){
	OCR2B = duty;
}