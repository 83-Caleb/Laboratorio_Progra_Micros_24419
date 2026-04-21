	
#ifndef PWM2_H_
#define PWM2_H_

#include <avr/io.h>

// Inicialización del PWM (Timer2 - OC2B / D3)
void PWM2_init(void);

// Función para cambiar el duty cycle
void PWM2_setDuty(uint16_t duty);

#endif /* PWM_H_ */