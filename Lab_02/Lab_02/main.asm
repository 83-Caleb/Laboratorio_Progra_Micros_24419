; Programación de Microcontroladores
; Lab 01
; Created: 02/02/2026
; Caleb Portillo - 24419

.include "M328PDEF.inc" // Nombres de registros específicos del ATmega328P

// ******************************************************************************************************************************************************************************
.org 0x00 // O ".org SRAM_START"
  		RJMP start
	
	start:
	// Configuración de "la pila"
		LDI R16, LOW(RAMEND) // LDI R16, 0xFF
		OUT SPL, R16 // Stack pointer low
		LDI R16, HIGH(RAMEND) // LDI R16 0x08
		OUT SPH, R16 // Ahora este tiene 0x08FF

	Table_7seg:
		.db 0xFF, 0xA0, 0x37, 0x76, 0xAC, 0x9E, 0x9F, 0xB0, 0xBF, 0xBC, 0xBD, 0x8F 

	// Configuración del oscilador a 2MHz
		LDI R16, (1<<CLKPCE) // Carga 0x80 (1000_0000)
		STS CLKPR, R16 // Enable del prescaler
		LDI R16, 0x03 // Set del CLKPS2 (0000_0011), que divide entre 8
		STS CLKPR, R16
	
	// Timer
		LDI R16, (1<<CS02) | (1<<CS00)
		OUT TCCR0B, R16
		LDI R16, 61
		OUT TCNT0, R16

	// DESHABILITAR ADC (Si no, no se puede usar PORTC como pines digitales (Se les conectaron las LEDs del contador)
		lds r16, ADCSRA
		cbr r16, (1 << ADEN)
		sts ADCSRA, r16

	// Deshabilitar UART (Para usar PD0 y PD1, que son Tx y Rx) (Se les conectaron pines del display)
		LDI R16, 0x00
		STS UCSR0B, R16

	// Puertos I/O
		LDI R16, 0x0F// 4 LEDs amarillas como output
		OUT DDRC, R16
		LDI R16, 0xFF // Todo el PORTC como OUTPUT para el display
		OUT DDRD, R16
		LDI R16, 0x00 // Todo el PORTC como INPUT para los botones
		OUT DDRB, R16

	// Configuración de LEDs y botones
		LDI R16, 0x00
		OUT PORTC, R16 // LEDs amarillas comienzan en 0
		LDI R16, 0x00
		OUT PORTD, R16 // Display comieza apagado
		LDI R16, 0x18
		OUT PORTB, R16 // Pin B4 y PB3 con resistencia Pull up
	
	// Configuración de z
		LDI ZH, HIGH(Table_7seg<<1)
		LDI ZL, LOW(Table_7seg<<1)

	// Registros a utilizar
		LDI R17, 0x00 // Valor actual del contador
		LDI R18, 0x00 // Contador de número de veces que se ha presionado el botón
		LDI R19, 0x00 // Para el antirrebote del botón
		LDI R20, 0x00 // Para leer la pulsación del botón
		LDI R21, 0x00 // Para almacenar el valor actual de Z

	Delay:
		// Cambiar el número del contador
		IN R16, TIFR0
		SBRS R16, TOV0
		RJMP Delay
		SBI TIFR0, TOV0 // Borrar banera
		LDI R16, 61
		OUT TCNT0, R16
		RCALL Incrementar

		// Leer el botón de suma cambia el display
		IN R20, PINB
		ANDI R20, 0x18 // Aislar Pin PB3 y 4
		CPI R20, 0x08 // Si son iguales, el botón se presionó
		BRNE Delay
		RJMP Antirrebote_display

	Incrementar:
		INC R17
		ANDI R17, 0x0F
		OUT PORTC, R17
		RET

	Antirrebote_display:
		IN R20, PINB // Verificamos que el botón siga presionado
		ANDI R20, 0x18
		CPI R20, 0x08
		BRNE Delay

		INC R19
		CPI R19, 250 // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Contador_display
		RJMP Delay

	Contador_display:
		IN R20, PINB // Verificamos que el botón se deje de pulsar
		ANDI R20, 0x18
		CPI R20, 0x08
		BREQ Contador_display		

		INC R18 // Incrementar el contador de número de veces que se ha presionado el botón
		LPM R21, Z+ // Guardar el número actual, z pasa al siguiente
		OUT PORTD, R21 // Mostrar el número
		
		ANDI R18, 0x0F
		CPI R18, 0x00
		BRNE Delay
		LDI ZH, HIGH(Table_7seg<<1)
		LDI ZL ,LOW(Table_7seg<<1)
		RJMP Delay