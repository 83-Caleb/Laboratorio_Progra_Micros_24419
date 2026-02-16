; Programación de Microcontroladores
; Lab 02
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
		.db 0xFB, 0xA0, 0x37, 0xB6, 0xAC, 0x9E, 0x9F, 0xB0, 0xBF, 0xBC, 0xBD, 0x8F, 0x1B, 0xA7, 0x1F, 0x1D

	// Configuración del oscilador a 2MHz
		LDI R16, (1<<CLKPCE) // Carga 0x80 (1000_0000)
		STS CLKPR, R16 // Enable del prescaler
		LDI R16, 0x03 // Set del CLKPS2 (0000_0011), que divide entre 8
		STS CLKPR, R16
	
	// Timer para 100ms
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
		LDI R16, 0x1F// 4 LEDs amarillas como output y la alarma en PC4
		OUT DDRC, R16
		LDI R16, 0xFF // Todo el PORTC como OUTPUT para el display
		OUT DDRD, R16
		LDI R16, 0x00 // Todo el PORTB como INPUT para los botones
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
		CLR R1 // Se usa en la máscara para no modificar el LED verde
		LDI R17, 0x00 // Valor actual del contador (LEDs amarillas)
		LDI R18, 0x00 // Valor actual del display de 7 segmentos
		LDI R19, 0x00 // Para el antirrebote del botón +
		LDI R20, 0x00 // Para el antirrebote del botón -
		LDI R21, 0x00 // Para leer la pulsación de los botones
		LDI R22, 0x00 // Para almacenar el valor actual de Z
		LDI R23, 0x00 // Para activar la LED verde
		LDI R24, 0x00 // Para contar 1s entre cambios de LEDs amarillas

		LPM R16, Z // Guardar el número actual (0 en el display)
		OUT PORTD, R16 // Mostrar el número 0

	Delay:
		// Regresamos el valor de Z a 0 en el display
		LDI ZH, HIGH(Table_7seg<<1)
		LDI ZL, LOW(Table_7seg<<1)

		// Leemos la pulsación del botón +
		IN R21, PINB
		ANDI R21, 0x10 // Para aislar el botón +
		CPI R21, 0x00 // Son iguales si se pulsó
		BREQ Antirrebote_inc

		// Leemos la pulsación del botón -
		IN R21, PINB
		ANDI R21, 0x08 // Para aislar el botón -
		CPI R21, 0x00 // Son iguales si se pulsó
		BREQ Antirrebote_dec

		// Reiniciamos antirrebote de ambos botones
		LDI R19, 0x00
		LDI R20, 0x00

		// Cambiar el número del contador
		IN R16, TIFR0
		SBRS R16, TOV0 // Skip si no han pasado 100ms todavía
		RJMP Delay
		SBI TIFR0, TOV0 // Borrar bandera
		LDI R16, 61 // Reconfigurar timer
		OUT TCNT0, R16
		INC R24 // Cada 10 ciclos, pasa 1 segundo
		CPI R24, 10
		BRNE Delay // Si no ha pasado 1s, regresar al bucle
		RCALL Incrementar // Al pasar 1s, incrementar el contador

		MOV R16, R17 // Para evitar que se haya errores en la comparación (porque el LED verde modifica el valor de R17)
		ANDI R16, 0x0F // Comparamos solo el valor de las LEDs amarillas
		CPSE R16, R18 // Skip si el contador y el display son iguales
		RJMP Delay

		LDI R17, 0x00 // Reiniciar contador
		COM R23 // Invierte todos los bits del registro
		CPSE R23, R1 // Skip si R23 es 0 para no encender el LED si estaba apagado
		ORI R17, 0x10 // Si R23 no es 0, mantener encendido el LED verde
		OUT PORTC, R17
		RJMP Delay
	
	Incrementar:
		INC R17 // Incrementar contador binario
		ANDI R17, 0x0F // Solo 4 bits con valor
		CPSE R23, R1 // Skip si R23 es 0 para no encender el LED si estaba apagado
		ORI R17, 0x10 // Si R23 no es 0, mantener encendido el LED verde
		OUT PORTC, R17
		CLR R1
		CLR R24
		RET

	Antirrebote_inc:
		IN R21, PINB // Confirmamos que siga presionado
		ANDI R21, 0x10 // Para aislar el botón +
		CPI R21, 0x00 // Son iguales si se pulsó
		BRNE Delay

		INC R19 // Incrementamos el valor de antirrebote
		CPI R19, 250 // Después de 10 ciclos, la pulsación es válida
		BRNE Antirrebote_inc
		
		CPI R18, 0x0F
		BREQ Overflow
		INC R18

		RCALL Cambiar_display
		RJMP Delay

	Antirrebote_dec:
		IN R21, PINB // Confirmamos que siga presionado
		ANDI R21, 0x08 // Para aislar el botón -
		CPI R21, 0x00 // Son iguales si se pulsó
		BRNE Delay

		INC R20 // Incrementamos el valor de antirrebote
		CPI R20, 250 // Después de 10 ciclos, la pulsación es válida
		BRNE Antirrebote_dec
		
		CPI R18, 0x00
		BREQ Underflow
		DEC R18
		RJMP Cambiar_display

	Underflow:
		LDI R18, 0x0F
		RJMP Cambiar_display

	Overflow:
		LDI R18, 0x00
		RJMP Cambiar_display

	Cambiar_display:
		IN R21, PINB // Confirmamos que no esté presionado ningún botón
		ANDI R21, 0x18 // Para aislar ambos botones
		CPI R21, 0x18 // Son iguales si ya no se pulsó
		BRNE Cambiar_display	

		ADD ZL, R18
		LPM R16, Z // Guardar el número actual
		OUT PORTD, R16 // Mostrar el número 0
		RJMP Delay