/*
 * PWM.h
 *
 * Created: 9/04/2026 15:47:16
 *  Author: Usuario
 */ 

#include <avr/io.h>
#ifndef PWM_H_
#define PWM_H_

void initPWM();
void updateDutyCicle0A(uint8_t ciclo);
void updateDutyCicle0B(uint8_t ciclo);

#endif /* PWM_H_ */