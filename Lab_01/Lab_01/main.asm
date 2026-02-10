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

	// Configuración del oscilador a 1MHz
		LDI R16, (1<<CLKPCE) // Carga 0x80 (1000_0000)
		STS CLKPR, R16 // Enable del prescaler
		LDI R16, (1<<CLKPS2) // Set del CLKPS2 (0000_0100), que divide entre 16
		STS CLKPR, R16

	// DESHABILITAR ADC (Si no, no se puede usar PORTC como pines digitales)
		lds r16, ADCSRA
		cbr r16, (1 << ADEN)
		sts ADCSRA, r16

	// Deshabilitar UART (Para usar PD0 y PD1, que son Tx y Rx) (Usé PD1 como botón sumador)
		LDI R16, 0x00
		STS UCSR0B, R16

	// Puertos I/O
		LDI R16, 0x1F
		OUT DDRB, R16 // PORTB: PB[4-0] como OUTPUT, PB[7-5] como INPUT
		LDI R16, 0xF0
		OUT DDRD, R16 // Bits más significativos del PORTD como OUTPUT, menos significativos como INPUT
		LDI R16, 0b0011_1100
		OUT DDRC, R16 // PORTC: PC[5-2] como output, el resto como INPUT

	// Configuración de LEDs y botones
		// Amarillo
		LDI R16, 0b0000_0000
		OUT PORTB, R16 // Contador empieza en 0x00
		// Azul
		LDI R16, 0b0000_1110 
		OUT PORTD, R16 // Nibble más significativo (contador) en 0, bits 1, 2 y 3 con resistencia Pull-up
		// Naranja
		LDI R16, 0b0000_0011 
		OUT PORTC, R16 // Bits 0 y 1 con resistencia Pull-up, display del sumador (naranja) apagado

	// Registros a utilizar
		LDI R17, 0x00 // Este es el registro que almacena el valor actual del contador amarillo
		LDI R18, 0x00 // Para confirmar el incremento del contador amarillo
		LDI R19, 0x00 // Para confirmar el decremento del contador amarillo
		LDI R20, 0x00 // Aquí se leerán las pulsaciones de los botones
		LDI R21, 0x00 // Este es el registro que almacena el valor actual del contador azul
		LDI R22, 0x00 // Para confirmar el incremento del contador azul
		LDI R23, 0x00 // Para confirmar el decremento del contador azul
		LDI R24, 0x00 // Este es el registro que almacena el valor actual del sumador (naranja)
		LDI R25, 0x00 // Para confirmar la pulsación del botón de suma

		//LDI R16, 0b0011_1111
		//OUT PORTC, R16

		//LDI R16, 0b0011_0000
		//OUT PORTB, R16

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

		LDI R18, 0x00 // Reinicio del contador de incremento
		LDI R19, 0x00 // Reinicio del contador de decremento

		IN R20, PIND // Lectura del botón de suma
		ANDI R20, 0x02 // Para aislar solo el botón de suma
		CPI R20, 0x00 // Botón de suma presionado
		BRNE Lectura
		RJMP Antirrebote_suma

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

		LDI R25, 0x00 // Reinicio del contador de la suma
		IN  R20, PORTB
		ANDI R20, 0b0011_0000 // Preservar PB5 (pull-up), PB4 (LED verde del overflow)
		OR  R20, R17 // Insertar el valor del contador amarillo en PB3–PB0
		OUT PORTB, R20
		CBI PORTB, 4
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
		ANDI R20, 0x02
		SBRS R20, 0x01 // Skip si el botón está presionado
		RJMP Lectura

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
		ORI R20, 0x0E // Devolvemos el pull-up en PD1, PD2 y PD3 
		OUT PORTD, R20 // Mostramos el valor 
		LDI R25, 0x00 // Reinicio del contador de la suma
		CBI PORTB, 4
		JMP Lectura

// ******************************************************************************************************************************************************************************
// Suma de contadores (Naranja)

	Antirrebote_suma:
		IN R20, PIND       // Verificamos que el botón siga presionado
		ANDI R20, 0x02 
		CPI R20, 0x00      // Botón presionado cuando PB5 es 0
		BRNE Regreso       // Si no está presionado, regresar

		INC R25
		CPI R25, 250       // Si se ha leído pulsación 250 veces seguidas, se acepta como válida
		BREQ Sumador_C
		RJMP Lectura

	Regreso:
		RJMP Lectura

	Sumador_C:
		IN R20, PIND       // Confirmamos que el botón ya no esté presionado 
		ANDI R20, 0x02
		CPI R20, 0x00      // Botón presionado = 0x00
		BREQ Sumador_C     // Mientras siga presionado, esperar	

		ANDI R17, 0b0000_1111 // Aseguramos que el valor amarillo no es mayor a 4 bits
		ANDI R21, 0b0000_1111 // Aseguramos que el valor azul no es mayor a 4 bits

		MOV R24, R17 // Copiamos el valor actual del contador amarillo
		ADD R24, R21 // Realizamos la suma entre ambos valores

		CLR R20
		MOV R20, R24 // Copiamos el resultado de la suma
		ANDI R20, 0xF0 // Aislamos el nibble más significativo para verificar si algún bit se encendió al sumar
		CPI R20, 0x00 // Si alguno se encendió, el resultado no es 0
		BREQ Mostrar_suma

		MOV R20, R17 // Copiamos el valor actual de las LED amarillas, para no modificar las luces
		ORI R20, 0b0011_0000 // Como hubo overflow, encendemos LED de overflow en PB4 (manteniendo pull-up en PB5)
		OUT PORTB, R20
		RJMP Mostrar_suma

	Mostrar_suma:
		ANDI R24, 0x0F // Nos quedamos solo con los 4 bits menos significativos
		LSL R24
		LSL R24 // Corremos el valor de la suma a 00XX_XX00, para que coincida con las LEDs
		ORI R24, 0x03 // Para devolver resistencia Pull-up a los botones de PC0 y PC1
		OUT PORTC, R24 // Se encienden las luces correspondientes a la suma
		LDI R25, 0x00 // Reinicio del contador de la suma
		RJMP Lectura