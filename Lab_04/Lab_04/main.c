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
#include <avr/pgmspace.h>

// Variables
volatile uint8_t contador = 0; // Valor actual del contador (usamos "volatile" porque el valor se modifica dentro de una ISR)
volatile uint8_t lock_inc = 0; // Para antirrebote INC
volatile uint8_t lock_dec = 0; // Para antirrebote DEC
volatile uint8_t medicion_ADC = 0; // Para leer el ADC
volatile uint8_t unidades = 0; // Unidades del display
volatile uint8_t decenas = 0; // Decenas del display
volatile uint8_t MUX_displays = 0; // Para multiplexar displays
volatile uint8_t LEDR_flag = 0; // Para saber si se debe encender la LED

#define BTN_INC PC5 // Nombre de los pines a los que conectamos los botones
#define BTN_DEC PC4

// Tabla para display de 7 segmentos
const uint8_t tabla7seg[] PROGMEM = { // Se guarda en la flash memory
	0xE7, // 0 
	0x82, // 1
	0xD5, // 2
	0xD3, // 3
	0xB2, // 4
	0x73, // 5
	0x77, // 6
	0xC2, // 7
	0xF7, // 8
	0xF2, // 9
	0xF6, // A
	0x37, // B
	0x65, // C
	0x97, // D
	0x75, // E
	0x74, // F
};

/*****************************************************************************************************************************************************/
// Function prototypes
int main(void); // Ciclo principal
void setup(); // Realiza todas las configuraciones
uint8_t invertir_nibble(uint8_t x); // Para invertir los nibbles del contador 
void mostrar_contador(uint8_t valor); // Para mostrar el valor en el contador

/*****************************************************************************************************************************************************/
// Main Function
int main(void){
	
	setup(); // Para realizar configuraciones
	sei(); // Para activar interrupciones globales
	
	while(1){ // Ciclo infinito
		
		mostrar_contador(contador); // Siempre estamos mostrando el valor actual del contador

		if (medicion_ADC > contador){
			LEDR_flag = 1;
		}
		else{
			LEDR_flag = 0;
		}
	}
	
}
/*****************************************************************************************************************************************************/
// NON-Interrupt subroutines
void setup(){
	
	// Reloj general
	CLKPR = (1<<CLKPCE); // Enable del prescaler
	CLKPR = (1<<CLKPS2); // Set del CLKPS2 (0000_0100), que divide entre 16
	
	// Deshabilitar UART (Para usar PD0 y PD1, que son Tx y Rx) (Se les conectaron pines del display)
	UCSR0B &= ~((1 << RXEN0) | (1 << TXEN0));		
	
	// Configuración de pines
	DDRD = 0xFF; // Todo PORTD como salida
	PORTD = 0x00; // PORTD empieza apagado
	
	DDRC = 0x0F; // Nibble bajo como salida, PORTC[5-4] como entrada
	PORTC |= (1 << BTN_INC) | (1 << BTN_DEC); // PC5-4 con Pull-Up activado
	
	DDRB = 0xFF;
	PORTB = 0x00;
	
	// Configuración de interrupciones por PIN-CHANGE
	PCICR |= (1 << PCIE1); // Enable
	PCMSK1 |= (1 << PCINT12) | (1 << PCINT13); // Pin/change para PC5-4
	
	// Interrupcion por Timer2
	TCCR2A = 0x00; // Timer2 en modo normal
	TCCR2B |= (1<<CS22); // Prescaler 64
	TCNT2 = 220; // Empezar a contar desde 220
	TIMSK2 |= (1<<TOIE2); // Enable del overflow interrupt
	
	// Configuración del ADC
	ADMUX = (1 << REFS0) | (1 << ADLAR) | (1 << MUX2) | (1 << MUX1); // Configuracion de la referencia del ADC, ADC6 activado y justificado a la izquierda, porque es mas conveniente
	ADCSRA |= (1 << ADEN) | (1 << ADIE); // ADC Enable e Interrupt Enable
	ADCSRA |= (1 << ADPS1) | (1 << ADPS0); // Prescaler de 8 para el ADC
	ADCSRA |= (1 << ADSC); // Empieza primera conversión
}

// Invertir nibble
uint8_t invertir_nibble(uint8_t nibble){ // Se crea la variable "nibble" como una copia del argumento enviado (valor de un nibble del contador)
	return  ((nibble & 0x01) << 3) | // El bit 0 se corre 3 a la izq
			((nibble & 0x02) << 1) | // El bit 1 se corre 1 a  la izq
			((nibble & 0x04) >> 1) | // El bit 2 se corre 1 a  la der
			((nibble & 0x08) >> 3); // El bit 3 se corre 3 a  la der
}

// Mostrar contador
void mostrar_contador(uint8_t valor){  // Se crea la variable interna "valor" que contiene una copia del argumento (contador)
    uint8_t low  = invertir_nibble(valor & 0x0F); // El nibble low es el resultado de invertir valor[3-0]
    uint8_t high = invertir_nibble((valor >> 4) & 0x0F); // Primero se corre a la derecha el nibble mayor y se hace máscara de estos valores

	// Mostramos el valor que corresponde en cada PORT
    PORTC = (PORTC & 0xF0) | low; // Primero se hace un AND para no modificar el resto del puerto y luego un OR para introducir el nibble mayor/menor
    PORTB = (PORTB & 0xF0) | high;
}

/*****************************************************************************************************************************************************/
// Interrupt routines

// Interrupcion por pinchange
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

// Por timer2
ISR(TIMER2_OVF_vect){
	
	TCNT2 = 220; // Reiniciamos la cuenta desde 220
    PORTB &= ~(1 << PB4); // Apagar ambos displays
    PORTB &= ~(1 << PB5); // El AND con PB5-4 en 0 fuerza el apagado
	PORTD = 0x00;
		
	if(MUX_displays == 0){
		
		MUX_displays = 1; // Para el siguiente ciclo
		PORTD = pgm_read_byte(&tabla7seg[unidades]); // Cargar unidades

		if (LEDR_flag == 1){ 
			PORTD |= (1 << PD3); // Encender la LEDR
		}
		else{
			PORTD &= (0b11110111); // AND para apagar la LEDR
		}
		
		PORTB |= (1 << PB4); // Encender unidades

	}
	
	else { // MUX_displays == 1
		
		MUX_displays = 0; // Para el siguiente ciclo
		PORTD = pgm_read_byte(&tabla7seg[decenas]); // Cargar decenas
		
		if (LEDR_flag == 1){
			PORTD |= (1 << PD3); // Encender la LEDR
		}
		else{
			PORTD &= (0b11110111); // AND para apagar la LEDR
		}
		
		PORTB |= (1 << PB5); // Encender decenas
	}
}

// Por ADC
ISR(ADC_vect){ // Interrupcion por ADC
	
	medicion_ADC = ADCH;
	
	unidades = (medicion_ADC & 0x0F); // Las unidades son el nibble bajo de ADCH
	decenas = (medicion_ADC >> 4) & 0x0F;
	
	ADCSRA |= (1 << ADSC); // Empezar conversión otra vez

}