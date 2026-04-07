// Universidad Del Valle de Guatemala
// Ingeniería Mecatrónica
// Programación de microcontroladores
// Laboratorio #4
// Caleb Portillo - 24419

/*****************************************************************************************************************************************************/
#define F_CPU 16000000UL

// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>

// Variables
volatile uint8_t contador = 0; // Valor actual del contador (usamos "volatile" porque el valor se modifica dentro de una ISR)
volatile uint8_t lock_inc = 0; // Para antirrebote INC
volatile uint8_t lock_dec = 0; // Para antirrebote DEC

#define BTN_INC PC5 // Nombre de los pines a los que conectamos los botones
#define BTN_DEC PC4

/*****************************************************************************************************************************************************/
// Function prototypes
int main(void);
void setup();

/*****************************************************************************************************************************************************/
// Main Function
int main(void){
	
	setup(); // Para realizar configuraciones
	sei(); // Para activar interrupciones globales
	
	while(1){ // Ciclo infinito
		
		PORTD = contador; // Siempre estamos mostrando el valor actual del contador en el PORTD
	}
	
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	
	// Configuración de pines
	DDRD = 0xFF; // Todo PORTD como salida
	PORTD = 0x00; // PORTD empieza apagado
	
	DDRC &= ~((1 << PC4) | (1 << PC5)); // PORTC[5-4] como entrada
	PORTC |= (1 << BTN_INC) | (1 << BTN_DEC); // PC5-4 con Pull-Up activado
	
	// Configuración de interrupciones por PIN-CHANGE
	PCICR |= (1 << PCIE1); // Enable
	PCMSK1 |= (1 << PCINT12) | (1 << PCINT13); // Pin/change para PC5-4
	
}

/*****************************************************************************************************************************************************/
// Interrupt routines
ISR(PCINT1_vect){
	uint8_t botones = PINC; 
	
	// INC
	if ( !(botones & (1 << BTN_INC)) ){ // Primero se hace una mascara para aislar el BIT del boton y luego se invierte para ver si esta en 0 (presionado)
		
		if(!lock_inc){ // Si el boton esta presionado (0), incrementamos
			
			contador++;
			lock_inc = 1; // Lockeamos para esperar a que se suelte, asi se diferencia flanco de bajada y se impiden multiples cambios
		}
		
	}
	
	else{ // Boton suelto
		lock_inc = 0;
	}
	
	// DEC
	if ( !(botones & (1 << BTN_DEC)) ){ // Primero se hace una mascara para aislar el BIT del boton y luego se invierte para ver si esta en 0 (presionado)
		
		if(!lock_dec){ // Si el boton esta presionado (0), incrementamos
			
			contador--;
			lock_dec = 1; // Lockeamos para esperar a que se suelte, asi se diferencia flanco de bajada y se impiden multiples cambios
		}
		
	}
	
	else{ // Boton suelto
		lock_dec = 0;
	}	
}