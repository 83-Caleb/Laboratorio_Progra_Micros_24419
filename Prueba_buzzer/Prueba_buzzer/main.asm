.include "M328PDEF.inc" // Nombres de registros específicos del ATmega328P

.dseg
cnt_LEDR: .byte 1

.cseg
.org 0x00 // O ".org SRAM_START"
  	RJMP start
	
.org OVF0addr // Interrupción por timer0
	RJMP ISR_timer0	
	
	start:
	CLI

	// Configuración de "la pila"
		LDI R16, LOW(RAMEND) // LDI R16, 0xFF
		OUT SPL, R16 // Stack pointer low
		LDI R16, HIGH(RAMEND) // LDI R16 0x08
		OUT SPH, R16 // Ahora este tiene 0x08FF

	// Configuración del oscilador general a 1MHz
		LDI R16, (1<<CLKPCE) // Carga 0x80 (1000_0000)
		STS CLKPR, R16 // Enable del prescaler
		LDI R16, (1<<CLKPS2) // Set del CLKPS2 (0000_0100), que divide entre 16
		//LDI R16, 0x00 // Borrar
		STS CLKPR, R16

	// Timer0 (Parpadeo de LEDs rojas)
		LDI R16, (1<<CS02)|(1<<CS00) // Prescaler de 1024
		OUT TCCR0B, R16
		LDI R16, 12 // Empezamos a contar en 12
		OUT TCNT0, R16
		LDI R16, (1<<TOIE0) // Enable de la interrupción Timer/Counter0
		STS TIMSK0, R16
		
		LDI R16, PORTB5
		OUT DDRB, R16 // Salida
		LDI R16, 0x00
		OUT PORTB, R16
		
		CLR R16
		STS cnt_LEDR, R16
		CLR R17
		CLR R18
		
	MAIN:
		RJMP MAIN
		
	// Interrupción por timer0
	ISR_timer0:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		
		LDI R16, 12 // Empezamos a contar en 12
		OUT TCNT0, R16

		LDS R17, cnt_LEDR
		INC R17
		STS cnt_LEDR, R17
		CPI R17, 2
		BRNE RETURN_ISR_timer0
		
		CLR R17
		STS cnt_LEDR, R17
		SBI PINB, PINB5

		RJMP RETURN_ISR_timer0

	RETURN_ISR_timer0:		
		POP R18
		POP R17
		POP R16
		OUT SREG, R16
		POP R16
		RETI 