; Programación de Microcontroladores
; Lab 02
; Caleb Portillo - 24419

.include "M328PDEF.inc" // Nombres de registros específicos del ATmega328P

.dseg // Se guardará el estado previo de los botones en la SRAM
botones: .byte 1
contador: .byte 1
L_ciclos: .byte 1
unidades_7seg: .byte 1

// *********************************************************************************************************************************************//
.cseg
.org 0x00 // O ".org SRAM_START"
  		RJMP start

.org PCI1addr // Interrupción para pin change en PORTC
	RJMP ISR_PCINT1

.org OVF0addr // Interrupción por timer
	RJMP ISR_timer
	
	start:
	CLI

	// Configuración de "la pila"
		LDI R16, LOW(RAMEND) // LDI R16, 0xFF
		OUT SPL, R16 // Stack pointer low
		LDI R16, HIGH(RAMEND) // LDI R16 0x08
		OUT SPH, R16 // Ahora este tiene 0x08FF

	// Configuración del oscilador a 2MHz
		LDI R16, (1<<CLKPCE) // Carga 0x80 (1000_0000)
		STS CLKPR, R16 // Enable del prescaler
		LDI R16, 0x03 // Set del CLKPS2 (0000_0011), que divide entre 8
		STS CLKPR, R16

	// Timer
		LDI R16, (1<<CS02) // CLK a 256
		OUT TCCR0B, R16
		LDI R16, 100 // Empezamos a contar en 100
		OUT TCNT0, R16
		LDI R16, (1<<TOIE0) // Enable de la interrupción Timer/Counter0
		STS TIMSK0, R16
		
	// DESHABILITAR ADC (Si no, no se puede usar PORTC como pines digitales (Se les conectaron las LEDs del contador y los botones)
		lds r16, ADCSRA
		cbr r16, (1 << ADEN)
		sts ADCSRA, r16

	// Deshabilitar UART (Para usar PD0 y PD1, que son Tx y Rx) (Se les conectaron pines del display)
		LDI R16, 0x00
		STS UCSR0B, R16

	// Puertos I/O
		LDI R16, 0x06 // PB2 es el enable del display der y PB1 el enable del display izq
		OUT DDRB, R16
		LDI R16, 0x0F // En 4-5 están los botones y en 0-3 están las LEDs rojas del display
		OUT DDRC, R16
		LDI R16, 0xFF // Display de 7 segmentos, todo OUTPUT
		OUT DDRD, R16

	// Configuración de LEDs y botones
		LDI R16, 0x06 // Ambos displays enabled
		OUT PORTB, R16
		LDI R16, 0x30 // PUll-up en 4-5 y contador apagado
		OUT PORTC, R16
		LDI R16, 0x00 // Displays apagados
		OUT PORTD, R16

	// Configuración de z
		LDI ZH, HIGH(Table_7seg<<1)
		LDI ZL, LOW(Table_7seg<<1)

	// Configurar interrupciones por pin change
		LDI R16, (1<<PCIE1) // Enable del PORTC
		STS PCICR, R16
		LDI R16, (1<<PCINT12)|(1<<PCINT13) // Selección de los bits PC4 y PC5 para interrupciones
		STS PCMSK1, R16

	// Registros a utilizar
		CLR R16
		LDI R17, 0x00 // Para leer la pulsación de los botones
		LDI R18, 0x00 // Para guardar el estado actual del contador de 4 bits (LEDs rojas)

		LDI R25, 0x00 // Lectura del botón PC4 (incremento)
		LDI R26, 0x00 // Lectura del botón PC5 (decremento)

		LDI R16, 0x30 // Estado inicial de los botones
		STS botones, R16

		LDI R16, 0x00 // Estado inicial del contador
		STS contador, R16

		LPM R16, Z // Guardar el número actual (0 en el display)
		OUT PORTD, R16 // Mostrar el número 0

		LDI R16, 0x00
		STS contador, R16
		LDI R16, 0x00          ; <-- Esto falta
		STS unidades_7seg, R16 ; <-- Agregar estas dos líneas
		LDI R16, 0x00
		STS L_ciclos, R16      ; También considera inicializar L_ciclos por la misma razón

		SEI // Habilitar interrupciones

// *********************************************************************************************************************************************//
// Código principal

    Main:
        JMP Main

// *********************************************************************************************************************************************//
// Interrupciones

// Pin-Change
	ISR_PCINT1:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		PUSH R25
		PUSH R26

		// Lectura de los botones
		IN R17, PINC
		ANDI R17, 0x30

		// Verificamos botón de incremento
		LDS R16, botones // Verificamos estado anterior de PC4
		ANDI R16, 0x10
		CPI R16, 0x00 // Si el estado anterior era 0, regresamos al programa principal
		BREQ ISR_return
		
		MOV R25, R17 // Aislamos lectura actual PC4
		ANDI R25, 0x10
		CPI R25, 0x00  // Si son iguales, el botón está presionado
		BREQ Boton_inc

		// Verificamos botón de decremento
		LDS R16, botones // Verificamos estado anterior de PC5
		ANDI R16, 0x20
		CPI R16, 0x00 // Si el estado anterior era 0, regresamos al programa principal
		BREQ ISR_return
		
		MOV R26, R17 // Aislamos lectura actual PC5
		ANDI R26, 0x20
		CPI R26, 0x00  // Si son iguales, el botón está presionado
		BREQ Boton_dec

	ISR_return:
		STS botones, R17 // Guardamos la lectura realizada como nuevo estado de los botones
		POP R26
		POP R25
		POP R18
		POP R17
		POP R16
		OUT  SREG, R16
		POP  R16
		RETI

	Boton_inc:
		LDS R18, contador
		INC R18
		RJMP Mostrar_contador

	Boton_dec:
		LDS R18, contador
		DEC R18
		RJMP Mostrar_contador

	Mostrar_contador:
		ANDI R18, 0x0F // Para tener valor solo en el nibble menor (LEDs)
		STS contador, R18
		MOV R16, R18
		ORI R16, 0x30 // Para devolver el pull-up a los botones en PC5-4
		OUT PORTC, R16		
		RJMP ISR_return

// Por timer
	ISR_timer:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18

		LDS R17, unidades_7seg
		LDS R16, L_ciclos
		INC R16
		CPI R16, 50 // Son iguales si ya pasaron 50 ciclos de 20ms
		BRNE Regreso_ISR_timer
		LDI R16, 0x00 // Reiniciar el contador de ciclos

		INC R17
		CPI R17, 0x10 // Si el display ya pasó de F, regresamos a 0
		BREQ Overflow
		RJMP Display_unidades

	Regreso_ISR_timer:

		LDI R18, 100 // Empezamos a contar en 100
		OUT TCNT0, R18

		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)

		STS L_ciclos, R16 // Guardamos los nuevos valores del contador de ciclos y el display
		STS unidades_7seg, R17
		POP R18
		POP R17
		POP R16
		OUT  SREG, R16
		POP  R16
		RETI

	Display_unidades:

		ADD ZL, R17
		LPM R18, Z // Guardar el número actual
		OUT PORTD, R18 // Mostrar el número 0
		RJMP Regreso_ISR_timer

	Overflow:
		LDI R17, 0x00
		RJMP Display_unidades
		
// *********************************************************************************************************************************************//
// Tablas de datos

	Table_7seg:
		.db 0xE7, 0x81, 0xD6, 0xD3, 0xB1, 0x73, 0x77, 0xC1, 0xF7, 0xF1, 0xF5, 0x37, 0x66, 0x97, 0x76, 0x74