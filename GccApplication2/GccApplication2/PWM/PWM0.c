/*
 * PWM0.c
 *
 * Created: 9/04/2026 15:47:42
 *  Author: Usuario
 */ 

#include "PWM0.h" // COmillas por ser librerias propias

void initPWM(){
	DDRD = (1<<DDD6)|(1<<DDD5);
	TCCR0A = 0;
	TCCR0B = 0;
	
	TCCR0A |= (1<<COM0A1); // No invertido
	TCCR0A |= (1<<COM0B1)|(1<<COM0B0); // Invertido
	TCCR0A |= (1<<WGM01)|(WGM00); // Modo fast
	
	TCCR0B |= (1<<CS01); // Prescaler 8
}

void updateDutyCicle0A(uint8_t ciclo){
	OCR0A = ciclo;
}

void updateDutyCicle0B(uint8_t ciclo){
	OCR0B = ciclo;
}