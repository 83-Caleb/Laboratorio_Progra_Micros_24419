
#ifndef PWM1_H_
#define PWM1_H_

#include <avr/io.h>

// Inicialización del PWM (Timer1 - OC1A / D9)
void PWM1_init(void);

// Función para cambiar el duty cycle (valor crudo)
void PWM1_setDuty(uint16_t duty);

#endif /* PWM1_H_ */