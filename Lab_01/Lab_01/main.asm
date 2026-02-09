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

	// Puertos I/O
		LDI R16, 0x0F
		OUT DDRB, R16 // Bits menos significativos del PORTB como OUTPUT, más significativos como INPUT
		LDI R16, 0xF0
		OUT DDRD, R16 // Bits más significativos del PORTD como OUTPUT, menos significativos como INPUT
		LDI R16, 0x00
		OUT DDRC, R16 // Bits del PORTC como INPUT

	// Configuración de LEDs
		// Amarillo
		LDI R16, 0x00
		OUT PORTB, R16 // Contador empieza en 0x00
		// Azul
		LDI R16, 0b00001100 
		OUT PORTD, R16 // Nibble más significativo (contador) en 0, bits 2 y 3 con resistencia Pull-up

	// Configuración de botones
		// Amarillo (ya se hizo)
		// Azul
		LDI R16, 0x03
		OUT PORTC, R16 // PORTC0 y PORTC1 con resistencia pull-up interna

	// Registros a utilizar
		LDI R17, 0x00 // Este es el registro que almacena el valor actual del contador amarillo
		LDI R18, 0X00 // Para confirmar el incremento del contador amarillo
		LDI R19, 0X00 // Para confirmar el decremento del contador amarillo
		LDI R20, 0x00 // Aquí se leerán las pulsaciones de los botones
		LDI R21, 0x00 // Este es el registro que almacena el valor actual del contador azul
		LDI R22, 0X00 // Para confirmar el incremento del contador azul
		LDI R23, 0X00 // Para confirmar el decremento del contador azul

	Lectura:
		IN R20, PIND // Lectura de los botones (Amarillo)
		ANDI R20, 0x0C // Para aislar solo los bits de los botones
		CPI R20, 0x08 // Botón + presionado
		BREQ Antirrebote_mas_Y
		CPI R20, 0x04 // Botón - presionado
		BREQ Antirrebote_menos_Y

		IN R20, PINC // Lectura de los botones (Azul)
		ANDI R20, 0x03 // Para aislar solo los bits de los botones
		CPI R20, 0x01 // Botón + presionado
		BREQ Antirrebote_mas_B
		CPI R20, 0x02 // Botón - presionado
		BREQ Antirrebote_menos_B
		
		LDI R18, 0X00 // Reinicio del contador del incremento
		LDI R19, 0X00 // Reinicio del contador de decremento
		RJMP Lectura

// ******************************************************************************************************************************************************************************
// Primer contador (Amarillo)

	Antirrebote_mas_Y:
		IN R20, PIND // Verificamos que el botón siga presionado
		ANDI R20, 0x0C
		CPI R20, 0x08
		BRNE Lectura

		INC R18
		CPI R18, 250 // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Sumar_Y
		LDI R19, 0X00 // Reinicio del contador de decremento
		RJMP Lectura

	Antirrebote_menos_Y:
		IN R20, PIND // Verificamos que el botón siga presionado
		ANDI R20, 0x0C
		CPI R20, 0x04
		BRNE Lectura

		INC R19
		CPI R19, 250 // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Restar_Y
		LDI R18, 0X00 // Reinicio del contador del incremento
		RJMP Lectura

	Sumar_Y:
		INC R17
		LDI R18, 0X00 // Reinicio del contador del incremento
		JMP Display_Contador_Y

	Restar_Y:
		DEC R17
		LDI R19, 0X00 // Reinicio del contador del decremento
		JMP Display_Contador_Y

	Display_Contador_Y:
		IN R20, PIND // Vamos a confirmar que el botón ya no esté presionado
		ANDI R20, 0x0C // Aislamos los 2 bits de botones
		CPI R20, 0x0C
		BRNE Display_Contador_Y // Si alguno de los botones sigue presionado, esperamos a que se libere

		OUT PORTB, R17
		JMP Lectura

// ******************************************************************************************************************************************************************************
// Segundo contador (Azul)

	Antirrebote_mas_B:
		IN R20, PINC // Verificamos que el botón siga presionado
		ANDI R20, 0x03
		CPI R20, 0x01
		BRNE Lectura

		INC R22
		CPI R22, 250 // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Sumar_B
		LDI R23, 0X00 // Reinicio del contador de decremento
		RJMP Lectura

	Antirrebote_menos_B:
		IN R20, PINC // Verificamos que el botón siga presionado
		ANDI R20, 0x03
		CPI R20, 0x02
		BRNE Lectura

		INC R23
		CPI R23, 250 // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Restar_B
		LDI R22, 0X00 // Reinicio del contador del incremento
		RJMP Lectura

	Sumar_B:
		INC R21
		LDI R22, 0X00 // Reinicio del contador del incremento
		JMP Display_Contador_B

	Restar_B:
		DEC R21
		LDI R23, 0X00 // Reinicio del contador del decremento
		JMP Display_Contador_B

	Display_Contador_B: 
		IN R20, PINC // Vamos a confirmar que el botón ya no esté presionado 
		ANDI R20, 0x03 // Aislamos los 2 bits de botones 
		CPI R20, 0x03
		BRNE Display_Contador_B // Si alguno de los botones sigue presionado, esperamos a que se libere
		MOV R20, R21 // Movemos el valor actual de contador a R20
		ANDI R20, 0x0F // Máscara para que solo los bits 0-3 tengan valor 
		SWAP R20 // Pasamos al nibble alto (bits 4–7, donde están las LEDs) 
		ORI R20, 0x0C // Devolvemos el pull-up en PD2 y PD3 
		OUT PORTD, R20 // Mostramos el valor 
		JMP Lectura