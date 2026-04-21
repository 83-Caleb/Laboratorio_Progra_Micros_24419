// Universidad Del Valle de Guatemala
// Ingeniería Mecatrónica
// Programación de microcontroladores
// Laboratorio #4
// Caleb Portillo - 24419

/*****************************************************************************************************************************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include "PWM/PWM1.h"
#include "PWM/PWM2.h"
#include "PWM/PWM_manual.h"

// Variables
volatile uint8_t medicion_ADC4 = 0; // Para leer el ADC4
volatile uint8_t medicion_ADC5 = 0; // Para leer el ADC5
volatile uint8_t medicion_ADC6 = 0; // Para leer el ADC6
uint16_t duty1 = 650; // Para el ciclo de trabajo, 1000 es el mínimo calculado (1ms)
uint8_t  duty2 = 12; // Para el ciclo de trabajo, 12 es el mínimo calculado (1ms)

#define SERVO1_MIN  650   // Pulso mínimo en ticks
#define SERVO1_MAX  2350   // Pulso máximo en ticks
#define SERVO2_MIN  6   // Pulso mínimo en ticks
#define SERVO2_MAX  18   // Pulso máximo en ticks

/*****************************************************************************************************************************************************/
// Function prototypes
int main(void); // Ciclo principal
void setup(); // Realiza todas las configuraciones

/*****************************************************************************************************************************************************/
// Main Function
int main(void){
	
	setup(); // Para realizar configuraciones
	PWM1_init(); // Para configurar el PWM1
	PWM2_init(); // Para configurar el PWM2
	PWMm_init(); // Para configurar el PWM0 manual
	sei(); // Para activar interrupciones globales
	
	while(1){ // Ciclo infinito
		
		duty1 = SERVO1_MIN + ((uint32_t)medicion_ADC6 * (SERVO1_MAX - SERVO1_MIN)) / 255;
		PWM1_setDuty(duty1); // Servo 1
		
		duty2 = SERVO2_MIN + ((uint32_t)medicion_ADC5 * (SERVO2_MAX - SERVO2_MIN)) / 255;
		PWM2_setDuty(duty2); // Servo 2
				
	}
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	
	// Reloj general
	CLKPR = (1<<CLKPCE); // Enable del prescaler
	CLKPR = (1<<CLKPS0); // Set del CLKPS2 (0000_0001), que divide entre 2 para trabajar a 8Mhz
	
	// Configuración del ADC, empieza el 6 activado
	ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2) | (1 << MUX1); // Configuracion de la referencia del ADC y justificado a la izquierda
	ADCSRA |= (1 << ADEN) | (1 << ADIE); // ADC Enable e Interrupt Enable
	ADCSRA |= (1 << ADPS2) | (1 << ADPS1); // Prescaler de 64 para el ADC
	ADCSRA |= (1 << ADSC); // Empieza primera conversión para ADC6
}


/*****************************************************************************************************************************************************/
// Interrupt routines

// Por ADC
ISR(ADC_vect){ // Interrupcion por ADC
	
	if ((ADMUX & 0x0F) == 0b0110){ // Estamos en ADC6
		medicion_ADC6 = ADCH;
		ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2) | (1 << MUX0); // En la próxima vamos al 5
	}
	
	else if ((ADMUX & 0x0F) == 0b0101){ // Estamos en ADC5
		medicion_ADC5 = ADCH;
		ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2); // En la próxima vamos al 4
	}
	
	else if ((ADMUX & 0x0F) == 0b0100){ // Estamos en ADC4
		medicion_ADC4 = ADCH;
		ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2) | (1 << MUX1); // En la próxima vamos al 6
	}
	
	ADCSRA |= (1 << ADSC); // Empezar conversión otra vez
}

// Por OVF del timer0 (se cumple el periodo de 32.77ms)
ISR(TIMER0_OVF_vect){
	
	// Si estamos en el minimo o maximo del POT, debemos deshabilitar el compare match para evitar errores
	
	if (medicion_ADC4 <= 5){ // Si el POT esta hasta abajo
		PORTB &= ~(1 << PORTB5); // Se apaga la LED
		TIMSK0 &= ~(1 << OCIE0A); // Desactivamos el output compare, que modifica el ancho de pulso
	}
	
	else if(medicion_ADC4 >= 250){ // Si el POT esta hasta arriba
		PORTB |= (1 << PORTB5); // Se enciende la LED
		TIMSK0 &= ~(1 << OCIE0A); // Desactivamos el output compare, que modifica el ancho de pulso
	}
	
	else{ // Cualquier valor de POT que si deba modificar el ancho de pulso
		PORTB |= (1 << PORTB5); // Se enciende la LED, se apagara con compare match
		OCR0A = medicion_ADC4; // La medicion del ADC4 determina el output compare, no hace falta mapeo porque ambos van de 0 a 255
		TIMSK0 |= (1 << OCIE0A); // Enable del output compare, que modifica el ancho de pulso
	}
}

// Por compare match del timer0 (Se determina el ancho de pulso)
ISR(TIMER0_COMPA_vect){ // Cuando TCNT0 = OCR0A, se debe enviar el puslo a 0
	PORTB &= ~(1 << PORTB5); // Se apaga la LED
}