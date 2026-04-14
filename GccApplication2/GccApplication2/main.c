/*
 * GccApplication2.c
 *
 * Created: 9/04/2026 15:22:05
 * Author : Usuario
 */ 

#define F_CPU 16000000
// Encabezado
#include <avr/io.h>
#include <util/delay.h>
#include "PWM/PWM0.h"

// Function prototipes
void setup();

int main(){
	uint8_t duty = 0;
	setup();
	initPWM();
	while(1){
		void updateDutyCicle0A(duty);
		void updateDutyCicle0A(duty);
		duty++;
		_delay_ms(1);
	}
}

void setup(){
	CLKPR = (1<<CLKPCE);
	CLKPR = (1<<CLKPS2);
}

