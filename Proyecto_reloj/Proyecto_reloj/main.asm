// Universidad Del Valle de Guatemala
// Ingeniería Mecatrónica
// Programación de Microcontroladores
// Proyecto Assembler: Reloj
// Caleb Portillo - 24419

.include "M328PDEF.inc" // Nombres de registros específicos del ATmega328P

// *********************************************************************************************************************************************//
// DATA SEGMENT: Registros que se almacenan en la SRAM
.dseg 
botones: .byte 1 // Para guardar el estado de los botones
disp_activo: .byte 1 // Para saber qué display está encendido en este instante

// Códigos HEX de cada display
disp_i1: .byte 1 // Display izquierda 1
disp_i2: .byte 1 // Display izquierda 2
disp_d1: .byte 1 // Display derecha 1
disp_d2: .byte 1 // Display derecha 2

// Contadores de unidades y decenas para cada medida de tiempo
cnt_LEDR: .byte 1

u_minutos: .byte 1
d_minutos: .byte 1
u_horas: .byte 1
d_horas: .byte 1
u_dias: .byte 1
d_dias: .byte 1
u_meses: .byte 1
d_meses: .byte 1

config: .byte 1 // Bandera de configuración [0xFF es config activada]
modo: .byte 1 // Indicador de modo (fecha/hora) [0xFF es modo fecha, 0x00 es modo hora]

// *********************************************************************************************************************************************//
// CODE SEGMENT: Comienza el programa
.cseg
.org 0x00 // O ".org SRAM_START"
  	RJMP start

.org PCI0addr // Interrupción para pin change en PORTB
	RJMP ISR_PCINT0

.org OVF2addr // Interrupción por timer2
	RJMP ISR_timer2

.org OVF1addr // Interrupción por timer1
	RJMP ISR_timer1

.org OVF0addr // Interrupción por timer0
	RJMP ISR_timer0
	
// *********************************************************************************************************************************************//
// Configuraciones generales del microcontrolador

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
		STS CLKPR, R16

	// DESHABILITAR ADC (Si no, no se puede usar PORTC como pines digitales (Se les conectaron LEDs y transistores)
		LDS r16, ADCSRA
		CBR r16, (1 << ADEN)
		STS ADCSRA, r16

	// Deshabilitar UART (Para usar PD0 y PD1, que son Tx y Rx) (Se les conectaron pines del display)
		LDI R16, 0x00
		STS UCSR0B, R16

	// Timer0 (Parpadeo de LEDs rojas)
		LDI R16, (1<<CS02)|(1<<CS00) // Prescaler de 1024
		OUT TCCR0B, R16
		LDI R16, 12 // Empezamos a contar en 12
		OUT TCNT0, R16
		LDI R16, (1<<TOIE0) // Enable de la interrupción Timer/Counter0
		STS TIMSK0, R16

	// Timer1 (contador de minutos)
		LDI R16, 0x00
		STS TCCR1A, R16 // Timer1 en modo normal
		LDI R16, (1<<CS12)|(1<<CS10)
		STS TCCR1B, R16 // Prescaler de 1024
		LDI R16, 0x1B
		STS TCNT1H, R16 // Valor inicial H para 60s
		LDI R16, 0x1E
		STS TCNT1L, R16 // Valor inicial L para 60s
		LDI R16, (1<<TOIE1)
		STS TIMSK1, R16 // Enable de la interrupción por overflow

	// Timer2 (para alternar displays de 7 segmentos)
		LDI R16, 0x00
		STS TCCR2A, R16 // Timer2 en modo normal
		LDI R16, (1<<CS22)|(1<<CS21) // Prescaler de 256
		STS TCCR2B, R16
		LDI R16, 250 // Empezar a contar desde 250
		STS TCNT2, R16
		LDI R16, (1<<TOIE2) // Enable del overflow interrupt
		STS TIMSK2, R16

	// Interrupciones por pin change
		LDI R16, (1<<PCIE0) // Enable del PORTB
		STS PCICR, R16
		LDI R16, (1<<PCINT0)|(1<<PCINT1)|(1<<PCINT2)|(1<<PCINT3)|(1<<PCINT4)  // Selección de los bits PB4-0 para interrupciones
		STS PCMSK0, R16

	// Puertos I/O
		LDI R16, 0x20 // PB4-0 tiene los botones, PB5 es para las LEDs rojas
		OUT DDRB, R16
		LDI R16, 0x3F // PC0 es la LED azul, PC1 es la LED verde, PC5-2 tiene los ENABLE de los displays
		OUT DDRC, R16
		LDI R16, 0xFF // Display de 7 segmentos, todo OUTPUT
		OUT DDRD, R16

	// Configuración de LEDs y botones
		LDI R16, 0x1F // Todos los botones con resistencia Pull-Up y LEDs R apagadas
		OUT PORTB, R16
		LDI R16, 0x3C // LEDs A/V apagadas y todos los displays enabled
		OUT PORTC, R16
		LDI R16, 0x00 // Displays apagados
		OUT PORTD, R16

	// Configuración del vector z
		LDI ZH, HIGH(Table_7seg<<1)
		LDI ZL, LOW(Table_7seg<<1)

	// Inicializar registros a utilizar

		// Registros en la SRAM
		LDI R16, 0x1F // Estado inicial de los botones (arriba en Pull-Up)
		STS botones, R16

		LPM R16, Z
		STS disp_i1, R16
		STS disp_i2, R16
		STS disp_d1, R16
		STS disp_d2, R16

		CLR R16 // Los demás registros comienzan en 0
		
		STS config, R16
		STS modo, R16
		STS disp_activo, R16
		
		STS cnt_LEDR, R16
		STS u_minutos, R16
		STS d_minutos, R16
		STS u_horas, R16
		STS d_horas, R16
		STS u_dias, R16
		STS d_dias, R16
		STS u_meses, R16
		STS d_meses, R16

		// Registros de propósito general
		CLR R16
		CLR R17
		CLR R18
		CLR R19
		CLR R20
		CLR R21
		CLR R22
		CLR R23
		CLR R24

		/*
		// Estado incial de los displays (solo durante la carga inicial)
		LPM R16, Z // Guardar el número actual (0 en el display)
		OUT PORTD, R16 // Mostrar el número 0 */

		SEI // Habilitar interrupciones globales

// *********************************************************************************************************************************************//
// Programa principal

	Verificar_CONFIG:
		LDS R16, config
		CPI R16, 0xFF
		BRNE CONFIG_0
		RJMP CONFIG_1

	CONFIG_1:
		SBI PORTC, 0
		SBI PORTC, 1
		RJMP Verificar_MODO

	CONFIG_0:
		CBI PORTC, 0
		CBI PORTC, 1
		RJMP Verificar_MODO

	Verificar_MODO:
		LDS R16, modo
		CPI R16, 0xFF
		BRNE HORA
		RJMP FECHA

	HORA:
		LDS R16, u_minutos
		STS disp_d2, R16
		LDS R16, d_minutos
		STS disp_d1, R16

		LDS R16, u_horas
		STS disp_i2, R16
		LDS R16, d_horas
		STS disp_i1, R16

		RJMP Verificar_CONFIG

	FECHA:
		LDS R16, u_dias
		STS disp_d2, R16
		LDS R16, d_dias
		STS disp_d1, R16

		LDS R16, u_meses
		STS disp_i2, R16
		LDS R16, d_meses
		STS disp_i1, R16
		
		RJMP Verificar_CONFIG

// *********************************************************************************************************************************************//
// Subrutinas de programa

// *********************************************************************************************************************************************//
// Subrutinas de interrupción

	// Interrupción para pin change en PORTB
	ISR_PCINT0: 
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		PUSH R19

		IN R17, PINB // Lectura del estado actual de los botones
		ANDI R17, 0x3F // Máscara para solo dejar PB5-0 con valor (no editamos el LED rojo)

		// Verificamos los botones 4-1 (Si actualmente son 1 [no presionado], se ignora la subrutina correspondiente)
		SBIS PINB, 1
		RJMP BOTON_1
		//SBIS PINB, 2
		//RJMP BOTON_2
		SBIS PINB, 3
		RJMP BOTON_3
		//SBIS PINB, 4
		//RJMP BOTON_4

		// Verificamos el botón 0 (config)
		MOV R18, R17 // Copia del estado actual de los botones
		ANDI R18, 0x01 // Aislamos bit 0
		CPI R18, 0x00 // Si es igual a 0, el botón se está presionando y CONFIG debe ser 0xFF
		BREQ BOTON_0

		LDI R18, 0x01 // Cargamos 1 en R18
		CLR R19 // Cargamos 0 en R19
		LDS R16, botones // Cargamos el estado anterior de los botones
		ANDI R16, 0x01 // Aislamos bit 0
		CPSE R16, R18 // Si son iguales (BOTON_0 = 1), el botón estaba suelto, así que no hubo flanco de subida y se ignora la siguiente línea
		STS config, R19 // Si no son iguales (BOTON_0 = 0), el botón estaba presionado y hubo flanco de subida, se resetea la bandera de config

		RJMP EXIT_ISR_PCINT0

	BOTON_0:
		LDI R16, 0xFF
		STS config, R16
		RJMP EXIT_ISR_PCINT0

	BOTON_1:
/*		LDS R16, config
		CPI R16, 0xFF
		BRNE EXIT_ISR_PCINT0

		INC disp_i1
		ADD Z, disp_i1 
		LPM R16, Z
		STS disp_i1, R16
		*/

	BOTON_3:
		LDS R19, modo
		CPI R16, 0x00
		BRNE BOTON_3A
		LDI R19, 0xFF
		STS modo, R19
		RJMP EXIT_ISR_PCINT0

	BOTON_3A:
		LDI R19, 0x00
		STS modo, R19
		RJMP EXIT_ISR_PCINT0
		

	EXIT_ISR_PCINT0:
		STS botones, R17 // Guardamos la lectura realizada como nueva lectura de botones
		POP R19
		POP R18
		POP R17
		POP R16
		OUT SREG, R16
		POP R16
		RETI

	// -------------------------------------------------------------------------------------------------------------------------------------------
	// Interrupción de timer2
	ISR_timer2:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		PUSH R19

		LDI R16, 250 // Empezamos a contar en 250
		STS TCNT2, R16

		IN R17, PORTC
		ANDI R17, 0b0000_0011 // No modificamos el valor de las LEDs
		OUT PORTC, R17 // Displays apagados por un instante

		LDS R18, disp_activo
		CPI R18, 0x00
		BREQ show_dispd2
		CPI R18, 0x01
		BREQ show_dispd1
		CPI R18, 0x02
		BREQ show_dispi2
		CPI R18, 0x03
		BREQ show_dispi1

	show_dispd2:
		INC R18
		LDS R17, disp_d2
		OUT PORTD, R17
		SBI PORTC, 4
		RJMP RETURN_ISR_timer2
	
	show_dispd1:
		INC R18
		LDS R17, disp_d1
		OUT PORTD, R17
		SBI PORTC, 5
		RJMP RETURN_ISR_timer2
	
	show_dispi2:
		INC R18
		LDS R17, disp_i2
		OUT PORTD, R17
		SBI PORTC, 3
		RJMP RETURN_ISR_timer2
	
	show_dispi1:
		CLR R18
		LDS R17, disp_i1
		OUT PORTD, R17
		SBI PORTC, 2
		RJMP RETURN_ISR_timer2

	RETURN_ISR_timer2:
		STS disp_activo, R18
		POP R19
		POP R18
		POP R17
		POP R16
		OUT SREG, R16
		POP R16
		RETI

	// -------------------------------------------------------------------------------------------------------------------------------------------
	ISR_timer1:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		PUSH R19
		PUSH R20
		PUSH R21
		PUSH R22
		PUSH R23
		PUSH R24

		LDI R16, 0x1B
		STS TCNT1H, R16 // Valor inicial H para 60s
		LDI R16, 0x1E
		STS TCNT1L, R16 // Valor inicial L para 60s

		LDS R17, u_minutos
		INC R17
		CPI R17, 0x0A
		BREQ INC_d_minutos
		STS u_minutos, R17
		RJMP RETURN_ISR_timer1

	INC_d_minutos:
		LDI R17, 0x00
		STS u_minutos, R17

		LDS R18, d_minutos
		INC R18
		CPI R18, 60
		BREQ INC_u_horas

		STS d_minutos, R18
		RJMP RETURN_ISR_timer1

	INC_u_horas:

	INC_d_horas:

	INC_u_dias:

	INC_d_dias:

	INC_u_meses:

	INC_d_meses:


	RETURN_ISR_timer1:
		POP R24
		POP R23
		POP R22
		POP R21
		POP R20
		POP R19
		POP R18
		POP R17
		POP R16
		OUT SREG, R16
		POP R16
		RETI

	// -------------------------------------------------------------------------------------------------------------------------------------------
	// Interrupción por timer0
	ISR_timer0:
		PUSH R16
		IN   R16, SREG
		PUSH R16
		PUSH R17
		PUSH R18
		PUSH R19
		PUSH R20
		
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
		POP R20
		POP R19
		POP R18
		POP R17
		POP R16
		OUT SREG, R16
		POP R16
		RETI 

// *********************************************************************************************************************************************//
// Tablas de datos

	Table_7seg: // Símbolos del 0 al 9
		.db 0x77, 0x42, 0x6D, 0x6B, 0x5A, 0x3B, 0x3F, 0x62, 0x7F, 0x7A