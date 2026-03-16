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
disp_config: .byte 1 // Para saber qué display estamos configurando

// Códigos HEX de cada display
disp_i1: .byte 1 // Display izquierda 1
disp_i2: .byte 1 // Display izquierda 2
disp_d1: .byte 1 // Display derecha 1
disp_d2: .byte 1 // Display derecha 2

// Contadores generales para cada medida de tiempo (unidades + decenas)
cnt_LEDR: .byte 1
cnt_horas: .byte 1
cnt_dias: .byte 1
cnt_meses: .byte 1

// Contadores de unidades y decenas para cada medida de tiempo
u_minutos: .byte 1
d_minutos: .byte 1
u_horas: .byte 1
d_horas: .byte 1
u_dias: .byte 1
d_dias: .byte 1
u_meses: .byte 1
d_meses: .byte 1

// Contadores para alarma
al_u_minutos: .byte 1
al_d_minutos: .byte 1
al_u_horas: .byte 1
al_d_horas: .byte 1

config: .byte 1 // Bandera de configuración [0xFF es config activada]
modo: .byte 1 // Indicador de modo (fecha/hora) [0xFF es modo fecha, 0x00 es modo hora, 0x55 es config alarma]

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
		//LDI R16, 0x00 // Borrar
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
		//LDI R16, (1<<CS11) // Borrar
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

		LPM R16, Z // Estado inicial de los displays (todos en 0)
		STS disp_i1, R16
		STS disp_i2, R16
		STS disp_d1, R16
		STS disp_d2, R16

		CLR R16 // Los demás registros comienzan en 0
		
		STS config, R16
		STS modo, R16
		STS disp_activo, R16
		STS disp_config, R16
		
		STS cnt_LEDR, R16
		STS cnt_horas, R16

		STS u_minutos, R16
		STS d_minutos, R16
		STS u_horas, R16
		STS d_horas, R16
		STS d_dias, R16
		STS d_meses, R16

		LDI R16, 0x01 // El modo fecha empieza desde el 1 de enero
		STS u_dias, R16
		STS u_meses, R16
		STS cnt_dias, R16
		STS cnt_meses, R16

		LDI R16, 0x00 // La alarma está programada por default para las 7 de la mañana
		STS al_u_minutos, R16
		STS	al_d_minutos, R16
		STS al_d_horas, R16
		LDI R16, 0x07
		STS al_u_horas, R16

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

		// Estado incial de los displays (solo durante la carga inicial)
		LPM R16, Z // Guardar el número actual (0 en el display)
		OUT PORTD, R16 // Mostrar el número 0

		SEI // Habilitar interrupciones globales

// *********************************************************************************************************************************************//
// Programa principal

// Subrutinas para mostrar fecha y hora según el modo

	Verificar_MODO:
		LDS R16, modo
		CPI R16, 0xFF
		BRNE HORA
		RJMP FECHA

	HORA:
		// Unidades de minutos
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, u_minutos
		ADD ZL, R16
		LPM R17, Z
		STS disp_d2, R17

		// Decenas de minutos
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, d_minutos
		ADD ZL, R16
		LPM R17, Z
		STS disp_d1, R17

		// Unidades de horas
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, u_horas
		ADD ZL, R16
		LPM R17, Z
		STS disp_i2, R17

		// Decenas de horas
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, d_horas
		ADD ZL, R16
		LPM R17, Z
		STS disp_i1, R17

		SBI PORTC, PORTC0
		CBI PORTC, PORTC1
		RJMP Verificar_OVF

	FECHA:
		// Unidades de dias
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, u_dias
		ADD ZL, R16
		LPM R17, Z
		STS disp_i2, R17

		// Decenas de dias
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, d_dias
		ADD ZL, R16
		LPM R17, Z
		STS disp_i1, R17

		// Unidades de meses
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, u_meses
		ADD ZL, R16
		LPM R17, Z
		STS disp_d2, R17

		// Decenas de meses
		LDI ZH, HIGH(Table_7seg<<1)	// Regresamos el valor de Z a 0 en el display
		LDI ZL, LOW(Table_7seg<<1)
		LDS R16, d_meses
		ADD ZL, R16
		LPM R17, Z
		STS disp_d1, R17
		
		SBI PORTC, PORTC1
		CBI PORTC, PORTC0
		RJMP Verificar_OVF

// Subrutinas de overflow para los contadores

	Verificar_OVF:
		LDS R17, u_minutos // Leemos las unidades de minutos que han pasado
		CPI R17, 0x0A // Si ya pasaron 10 u_minutos, hacemos overflow a decenas de minutos
		BRSH INC_d_minutos

		LDS R18, d_minutos // Leemos las decenas de minutos que han pasado
		CPI R18, 0x06 // Si ya pasaron 60 minutos, hacemos overflow a unidades de hora
		BRLO PC+2
		RJMP INC_u_horas
		
		LDS R19, u_horas // Leemos las unidades de horas que han pasado
		CPI R19, 0x0A // Si ya pasaron 10 horas, hacemos overflow a decenas de hora
		BRLO PC+2
		RJMP INC_d_horas
		
		LDS R17, cnt_horas // Leemos las horas totales que han pasado (0 a 24)
		CPI R17, 24 // Si ya pasaron 24 horas, incrementamos el dia
		BRLO PC+2
		RJMP INC_u_dias_A
		
		LDS R21, u_dias // Leemos las unidades de días que han pasado
		CPI R21, 0x0A // Si ya pasaron 10, hacemos overflow a decenas de días
		BRLO PC+2
		RJMP INC_d_dias

		LDS R22, d_dias
		CPI R22, 0x04 // Impedimos que se pueda cargar más de 4 decenas de días en el modo config
		BRNE Verificar_OVF_cnt_dias
		CLR R22
		STS d_dias, R22
		
		Verificar_OVF_cnt_dias:
		LDS R17, cnt_dias // Cargamos el contador actual de dias

		LDS R18, cnt_meses // Tenemos que verificar si estamos en febrero, que es un caso especial
		CPI R18, 2
		BRNE PC+4 // Si no, saltamos al siguiente bloque
		CPI R17, 29
		BRLO PC+2 // Si estamos en un día mayor o igual a 29, nos vamos a incrementar meses
		RJMP INC_u_meses

		CPI R17, 32 // Si ya pasaron 31 días, toca incrementar el mes
		BRLO PC+2
		RJMP INC_u_meses
		CPI R17, 31 // Si ya pasaron 30 días, verificamos en qué mes estamos
		BRLO PC+2
		RJMP V_30_DIAS
		CPI R17, 29 // Si ya pasaron 28 días, verificamos si estamos en febrero
		BRLO PC+2
		RJMP V_28_DIAS

		LDS R23, u_meses
		CPI R23, 0x0A // Si se incrementa de 9 a 10 meses, debemos hacer overflow en unidades de meses
		BRLO PC+2
		RJMP INC_d_meses
		
		LDS R18, cnt_meses // Revisamos si ya pasaron 12 meses para reiniciar
		CPI R18, 13
		BRLO PC+2
		RJMP Reinicio_reloj

		RJMP Verificar_MODO

	INC_d_minutos:
		CLR R17
		STS u_minutos, R17 // Reiniciamos u_minutos, pasa de 9 a 0

		LDS R18, d_minutos // Leemos las decenas de minutos que han pasado
		INC R18 // Aumentamos las decenas de minutos
		CPI R18, 0x06 // Si ya pasaron 60 minutos, hacemos overflow a unidades de hora
		BRSH INC_u_horas

		STS d_minutos, R18
		RJMP Verificar_MODO

	INC_u_horas:
		CLR R18
		STS d_minutos, R18 // Reiniciamos d_minutos, pasa de 5 a 0 (59 a 00 en los display d)

		LDS R17, cnt_horas // Leemos las horas totales que han pasado (0 a 24)
		INC R17 // Aumentamos 1
		CPI R17, 24 // Si ya pasaron 24 horas, incrementamos el dia
		BRSH INC_u_dias_A

		STS cnt_horas, R17 // Guardamos el nuevo valor de horas generales

		LDS R19, u_horas // Leemos las unidades de horas que han pasado
		INC R19 // Incrementamos
		CPI R19, 0x0A // Si ya pasaron 10 horas, hacemos overflow a decenas de hora
		BRSH INC_d_horas

		STS u_horas, R19
		RJMP Verificar_MODO

	INC_d_horas: // Si entramos a esta subrutina, es porque no está ocurriendo incremento de día
		CLR R19
		STS u_horas, R19 // Reiniciamos unidades de horas

		LDS R20, d_horas // Leemos las decenas de horas que han pasado
		INC R20
		STS d_horas, R20 // Guardamos el nuevo valor
		RJMP Verificar_MODO

	INC_u_dias_A:
		CLR R16 // Reiniciamos los contadores de horas
		STS cnt_horas, R16
		STS u_horas, R16
		STS d_horas, R16		

		LDS R17, cnt_dias // Cargamos el día actual e incrementamos 1
		INC R17

		CPI R17, 32 // Si ya pasaron 31 días, toca incrementar el mes
		BRSH INC_u_meses
		
		CPI R17, 31 // Si ya pasaron 30 días, verificamos en qué mes estamos
		BRSH V_30_DIAS
		
		CPI R17, 29 // Si ya pasaron 28 días, verificamos si estamos en febrero
		BRSH V_28_DIAS

	INC_u_dias_B:
		STS cnt_dias, R17 // Si no se activa ninguna de esas subrutinas, guardamos el valor nuevo de cnt_dias

		LDS R16, config
		CPI R16, 0xFF
		BRNE PC+2
		RJMP Verificar_modo

		LDS R21, u_dias
		INC R21
		CPI R21, 0x0A
		BRSH INC_d_dias

		STS u_dias, R21
		RJMP Verificar_MODO

	INC_d_dias:
		CLR R21
		STS u_dias, R21

		LDS R22, d_dias
		INC R22
		STS d_dias, R22
		RJMP Verificar_MODO

	V_28_DIAS: // Si estamos en febrero, el mes cambia después de 28 días
		LDS R16, cnt_meses
		CPI R16, 2
		BRNE INC_u_dias_B // Si no estamos en febrero, regresamos al flujo de incremento normal
		RJMP INC_u_meses

	V_30_DIAS:
		LDS R16, cnt_meses

		CPI R16, 4 // Estamos en abril?
		BREQ INC_u_meses

		CPI R16, 6 // Estamos en junio?
		BREQ INC_u_meses

		CPI R16, 9 // Estamos en septiembre?
		BREQ INC_u_meses

		CPI R16, 11 // Estamos en noviembre?
		BREQ INC_u_meses

		RJMP INC_u_dias_B

	INC_u_meses:
		LDI R17, 0x01 // Los contadores de días vuelven a empezar desde 01
		STS cnt_dias, R17
		STS u_dias, R17
		CLR R17
		STS d_dias, R17

		LDS R18, cnt_meses
		INC R18
		CPI R18, 13
		BRSH Reinicio_reloj
		STS cnt_meses, R18

		LDS R23, u_meses
		INC R23
		CPI R23, 0x0A
		BRSH INC_d_meses

		STS u_meses, R23
		RJMP Verificar_MODO

	INC_d_meses:
		CLR R23
		STS u_meses, R23

		LDS R24, d_meses
		INC R24
		STS d_meses, R24
		RJMP Verificar_MODO

	Reinicio_reloj:
		LDI R20, 0x01
		STS cnt_meses, R20
		STS u_meses, R20
		CLR R20
		STS d_meses, R20
		RJMP Verificar_MODO

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
		PUSH R20
		PUSH R21
		PUSH R22

		IN R17, PINB // Lectura del estado actual de los botones
		ANDI R17, 0x3F // Máscara para solo dejar PB5-0 con valor (no editamos el LED rojo)

		// Verificamos los botones 4-1 (Si actualmente son 1 [no presionado], se ignora la subrutina correspondiente)
		SBIS PINB, 1
		RJMP BOTON_1
		SBIS PINB, 2
		RJMP BOTON_2
		SBIS PINB, 3
		RJMP BOTON_3
		SBIS PINB, 4
		RJMP BOTON_4

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
		STS config, R16 // Activamos configuración: config = 0xFF
		RJMP EXIT_ISR_PCINT0

	BOTON_1: // Botón de incremento
		LDS R16, config
		CPI R16, 0x00
		BRNE ACCION_B1
		RJMP EXIT_ISR_PCINT0 // Si no estamos en configuración, no tiene efecto la pulsación

		ACCION_B1:
		LDS R16, modo
		CPI R16, 0x00
		BREQ B1_HORA // Branch si estamos en modo hora
		CPI R16, 0xFF
		BREQ B1_FECHA // Branch si estamos en modo fecha

		B1_HORA:
			LDS R17, disp_config // Incrementamos el valor del display seleccionado (cambia con el B4)
			
			CPI R17, 0x00
			BREQ INC_CONFIG_U_MINUTOS // disp_config = 0 incrementa u_minutos
			CPI R17, 0x01
			BREQ INC_CONFIG_D_MINUTOS // disp_config = 1 incrementa d_minutos
			CPI R17, 0x02
			BREQ INC_CONFIG_U_HORAS // disp_config = 2 incrementa u_horas
			CPI R17, 0x03
			BRSH INC_CONFIG_D_HORAS // disp_config = 3 incrementa d_horas

			INC_CONFIG_U_MINUTOS: // Aumentamos 1 minuto
				LDS R19, u_minutos
				INC R19
				STS u_minutos, R19
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_D_MINUTOS: // Aumentamos 10 minutos
				LDS R19, d_minutos
				INC R19
				STS d_minutos, R19
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_U_HORAS: // Aumentamos 1 hora (en contador general y en el de unidades)
				LDS R19, u_horas 
				INC R19
				STS u_horas, R19

				LDS R20, cnt_horas 
				INC R20
				STS cnt_horas, R20
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_D_HORAS: // Aumentamos 10 horas en contador general y 1 en el de decenas
				LDS R19, d_horas 
				INC R19
				STS d_horas, R19

				LDS R20, cnt_horas
				LDI R21, 0x0A 
				ADD R20, R21
				STS cnt_horas, R20
				RJMP EXIT_ISR_PCINT0

		B1_FECHA:
			LDS R17, disp_config // Incrementamos el valor del display seleccionado (cambia con el B4)
			
			CPI R17, 0x00
			BREQ INC_CONFIG_U_DIAS // disp_config = 0 incrementa u_dias
			CPI R17, 0x01
			BREQ INC_CONFIG_D_DIAS // disp_config = 1 incrementa d_dias
			CPI R17, 0x02
			BREQ INC_CONFIG_U_MESES // disp_config = 2 incrementa u_meses
			CPI R17, 0x03
			BRSH INC_CONFIG_D_MESES // disp_config = 3 incrementa d_meses

			INC_CONFIG_U_DIAS: // Aumentamos 1 dia (en contador general y en el de unidades)
				LDS R19, u_dias
				INC R19
				STS u_dias, R19
				
				LDS R20, cnt_dias 
				INC R20
				STS cnt_dias, R20
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_D_DIAS: // Aumentamos 10 dias en el contador general y 1 en el de decenas
				LDS R19, d_dias
				INC R19
				STS d_dias, R19
				
				LDS R20, cnt_dias
				LDI R21, 0x0A 
				ADD R20, R21
				STS cnt_dias, R20
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_U_MESES: // Aumentamos 1 mes (en contador general y en el de unidades)
				LDS R19, u_meses 
				INC R19
				STS u_meses, R19

				LDS R20, cnt_meses
				INC R20
				STS cnt_meses, R20
				RJMP EXIT_ISR_PCINT0

			INC_CONFIG_D_MESES: // Aumentamos 10 meses en el contador general y 1 en el de decenas
				LDS R19, d_meses
				INC R19
				STS d_meses, R19

				LDS R20, cnt_meses
				LDI R21, 0x0A 
				ADD R20, R21
				STS cnt_meses, R20
				RJMP EXIT_ISR_PCINT0

		RJMP EXIT_ISR_PCINT0
		
	BOTON_2: // Botón de decremento
		LDS R16, config
		CPI R16, 0x00
		BRNE ACCION_B2
		RJMP EXIT_ISR_PCINT0 // Si no estamos en configuración, no tiene efecto la pulsación

		ACCION_B2:
		LDS R16, modo
		CPI R16, 0x00
		BREQ B2_HORA // Branch si estamos en modo hora

		RJMP B2_FECHA // Branch si estamos en modo fecha (no estamos en hora ni en alarma)

		B2_HORA:
			LDS R17, disp_config // Decrementamos el valor del display seleccionado (cambia con el B4)
			
			CPI R17, 0x00
			BREQ DEC_CONFIG_U_MINUTOS // disp_config = 0 decrementa u_minutos
			CPI R17, 0x01
			BREQ DEC_CONFIG_D_MINUTOS // disp_config = 1 decrementa d_minutos
			CPI R17, 0x02
			BREQ DEC_CONFIG_U_HORAS // disp_config = 2 decrementa u_horas

			RJMP DEC_CONFIG_D_HORAS // disp_config = 3 o más, decrementa d_horas

			DEC_CONFIG_U_MINUTOS: // Regresamos 1 minuto
				LDS R19, u_minutos
				CPI R19, 0x00
				BRNE PC+5 // salta LDI(1) + STS(2) + RJMP(1) = 4
				LDI R19, 0x09 // tarda 1 ciclo
				STS u_minutos, R19 // tarda 2 ciclos (hay que tomarlo en cuenta)
				RJMP EXIT_ISR_PCINT0 // tarda 1 ciclo
				
				DEC R19
				STS u_minutos, R19
				RJMP EXIT_ISR_PCINT0

			DEC_CONFIG_D_MINUTOS: // Regresamos 10 minutos
				LDS R19, d_minutos
				CPI R19, 0x00
				BRNE PC+5
				LDI R19, 0x05
				STS d_minutos, R19
				RJMP EXIT_ISR_PCINT0
				
				DEC R19
				STS d_minutos, R19
				RJMP EXIT_ISR_PCINT0

			DEC_CONFIG_U_HORAS: // Regresamos 1 hora (en contador general y en el de unidades)
				LDS R20, cnt_horas
				CPI R20, 0x00 // Si estamos en 00 horas, regresar a 23
				BREQ UNDERFLOW_HORAS
				
				LDS R19, d_horas
				CPI R19, 0x00 // Si las decenas de hora no son 0, verificamos si hay underflow
				BREQ PC+5 // Porque LDS tarda 2 ciclos
				LDS R18, u_horas
				CPI R18, 0x00 // Si hay underflow, saltamos a UNDERFLOW_U_HORAS
				BREQ UNDERFLOW_U_HORAS
				
				LDS R18, u_horas // Si no hay underflow de ningún tipo, solo decrementamos las unidades y el contador
				DEC R18
				STS u_horas, R18
				LDS R20, cnt_horas
				DEC R20
				STS cnt_horas, R20
				RJMP EXIT_ISR_PCINT0
				
				UNDERFLOW_U_HORAS: // Pasamos de 10 a 09 o de 20 a 19 horas
					LDS R20, cnt_horas 
					DEC R20 // Disminuye el contador general en 1
					STS cnt_horas, R20
					LDS R19, d_horas
					DEC R19 // Disminuye las decenas en 1
					STS d_horas, R19
					LDI R18, 0x09 // Regresamos las unidades a 9 
					STS u_horas, R18
					RJMP EXIT_ISR_PCINT0
					
				UNDERFLOW_HORAS: // Pasamos de 00 a 23 horas
					LDI R20, 23
					STS cnt_horas, R20 // Regresamos el contador a 23 horas
					LDI R19, 0x02
					STS d_horas, R19 // Regresamos las decenas a 2
					LDI R19, 0X03
					STS u_horas, R19 // Regresamos las unidades a 3
					RJMP EXIT_ISR_PCINT0

			DEC_CONFIG_D_HORAS: // Regresamos 10 horas en contador general y 1 en el de decenas
				LDS R20, cnt_horas
				CPI R20, 0x0A // Si en el contador general hay menos de 10 horas, hacemos underflow
				BRLO UNDERFLOW_D_HORAS
				
				LDS R19, d_horas 
				DEC R19
				STS d_horas, R19

				LDS R20, cnt_horas
				SUBI R20, 0x0A
				STS cnt_horas, R20
				RJMP EXIT_ISR_PCINT0
				
				UNDERFLOW_D_HORAS: // Pasamos a 23 horas
					LDI R20, 23
					STS cnt_horas, R20 // Regresamos el contador a 23 horas
					LDI R19, 0x02
					STS d_horas, R19 // Regresamos las decenas a 2
					LDI R19, 0X03
					STS u_horas, R19 // Regresamos las unidades a 3
					RJMP EXIT_ISR_PCINT0

		B2_FECHA:
			LDS R17, disp_config // Incrementamos el valor del display seleccionado (cambia con el B4)
			
			CPI R17, 0x00
			BREQ DEC_CONFIG_U_DIAS // disp_config = 0 decrementa u_dias
			
			CPI R17, 0x01
			BRNE PC+2
			RJMP DEC_CONFIG_D_DIAS // disp_config = 1 decrementa d_dias
			
			CPI R17, 0x02
			BRNE PC+2
			RJMP DEC_CONFIG_U_MESES // disp_config = 2 decrementa u_meses

			RJMP DEC_CONFIG_D_MESES // disp_config = 3+ decrementa d_meses

			DEC_CONFIG_U_DIAS: // Regresamos 1 dia (en contador general y en el de unidades)
				LDS R20, cnt_dias // Verificamos si hay que hacer underflow, regresando a la cantidad máxima de días de cada mes
				CPI R20, 0x01
				BREQ UNDERFLOW_28_DIAS
				
				LDS R18, d_dias
				CPI R18, 0x00 // Decenas en 0?
				BREQ PC+5 // Si las decenas están en 1, 2 o 3, verificamos si los días están en 0
				LDS R19, u_dias
				CPI R19, 0x00
				BREQ UNDERFLOW_U_DIAS // Saltamos a hacer el underflow

				LDS R20, cnt_dias // Si no hay que hacer underflow, solo disminuimos una unidad de día de ambos contadores
				DEC R20
				STS cnt_dias, R20
				LDS R19, u_dias
				DEC R19
				STS u_dias, R19
				RJMP EXIT_ISR_PCINT0

				UNDERFLOW_U_DIAS: // Pasamos de 10 a 09, 20 a 19 o 30 a 29
					LDS R20, cnt_dias
					DEC R20
					STS cnt_dias, R20 // Restamos 1 día al contador
					LDS R18, d_dias
					DEC R18
					STS d_dias, R18 // Restamos 1 a decenas de día
					LDI R19, 0x09
					STS u_dias, R19 // Decenas de días a 9
					RJMP EXIT_ISR_PCINT0

				UNDERFLOW_28_DIAS:
					LDS R16, cnt_meses
					CPI R16, 0x02
					BRNE UNDERFLOW_31_DIAS // Si no estamos en febrero, verificamos en qué mes estamos
				
					LDI R18, 28 // Si estamos en febrero regresamos a 28 días
					STS cnt_dias, R18
					LDI R19, 0x08 // Cargamos una unidad de día
					STS u_dias, R19
					LDI R20, 0x02 // Cargamos 2 decenas de día
					STS d_dias, R20
					RJMP EXIT_ISR_PCINT0

				UNDERFLOW_31_DIAS:
					LDS R16, cnt_meses // Buscamos si estamos en un mes con 30 días
					CPI R16, 0x04 // Abril
					BREQ UNDERFLOW_30_DIAS 
					CPI R16, 0x06 // Junio
					BREQ UNDERFLOW_30_DIAS 
					CPI R16, 0x09 // Septiembre
					BREQ UNDERFLOW_30_DIAS 
					CPI R16, 0x0B // Noviembre
					BREQ UNDERFLOW_30_DIAS 

					LDI R18, 31 // Si seguimos en esta subrutina, el mes en el que estamos tiene 31 días
					STS cnt_dias, R18
					LDI R19, 0x01 // Cargamos una unidad de día
					STS u_dias, R19
					LDI R20, 0x03 // Cargamos 1 decena de día
					STS d_dias, R20
					RJMP EXIT_ISR_PCINT0

				UNDERFLOW_30_DIAS:
					LDI R18, 30 // Si caemos en esta subrutina, el mes en el que estamos tiene 30 días
					STS cnt_dias, R18
					LDI R19, 0x00 // Cargamos 0 como unidad de día
					STS u_dias, R19
					LDI R20, 0x03 // Cargamos 3 decenas de día
					STS d_dias, R20
					RJMP EXIT_ISR_PCINT0
			
			DEC_CONFIG_D_DIAS: // Restamos 10 días a los contadores
					LDS R18, d_dias
					LDI R21, 0x0A
					MUL R18, R21    
					LDS R19, u_dias
					ADD R0, R19 // cnt_dias = d_dias*10 + u_dias
					MOV R18, R0
					STS cnt_dias, R18

					CPI R18, 0x0B
					BRLO UNDERFLOW_28_DIAS // Si el contador de días es igual o menor a 10 y restamos 10, cargamos los días máximos del mes correspondiente
					SUBI R18, 0x0A
					STS cnt_dias, R18
					LDS R19, d_dias
					DEC R19
					STS d_dias, R19
					RJMP EXIT_ISR_PCINT0

			DEC_CONFIG_U_MESES:
				LDS R18, d_meses //cnt_meses = d_meses*10 + u_meses
				LDI R21, 0x0A
				MUL R18, R21      
				LDS R19, u_meses
				ADD R0, R19
				MOV R18, R0
				STS cnt_meses, R18  

				CPI R18, 0x01
				BREQ UNDERFLOW_MESES
				DEC R18
				STS cnt_meses, R18
				LDS R19, u_meses
				DEC R19
				CPI R19, 0xFF // Verificamos si hubo underflow
				BREQ UNDERFLOW_D_MESES
				STS u_meses, R19
				RJMP EXIT_ISR_PCINT0
				
				UNDERFLOW_D_MESES: // Pasamos de 10 a 09
					LDI R19, 0x09
					STS u_meses, R19
					CLR R20
					STS d_meses, R20
					RJMP EXIT_ISR_PCINT0

				UNDERFLOW_MESES: // Cargamos diciembre
					LDI R18, 12
					STS cnt_meses, R18 // Contador a 12
					LDI R19, 0x02
					STS u_meses, R19 // Unidades a 2
					LDI R20, 0x01
					STS d_meses, R20 // Decenas a 1
					RJMP EXIT_ISR_PCINT0

			DEC_CONFIG_D_MESES:
				LDS R18, d_meses // cnt_meses = d_meses*10 + u_meses
				LDI R21, 0x0A
				MUL R18, R21
				LDS R19, u_meses
				ADD R0, R19
				MOV R18, R0
				STS cnt_meses, R18

				CPI R18, 0x0B
				BRLO UNDERFLOW_MESES // Si el valor del contador era igual o menor a 10 y restamos 10, cargamos diciembre
				SUBI R18, 0x0A
				STS cnt_meses, R18
				LDS R19, d_meses
				DEC R19
				STS d_meses, R19
				RJMP EXIT_ISR_PCINT0

	BOTON_3: // Botón de cambio de modo
		LDS R19, modo
		CPI R19, 0x00
		BRNE BOTON_3A
		LDI R19, 0xFF
		STS modo, R19
		RJMP EXIT_ISR_PCINT0

		BOTON_3A: // Reset de modo
			LDI R19, 0x00
			STS modo, R19
			RJMP EXIT_ISR_PCINT0
	
	BOTON_4: // Botón para cambiar de display que se está configurando
		LDS R21, config // revisamos si estamos en CONFIG desactivada
		CPI R21, 0x00
		BREQ EXIT_ISR_PCINT0 // Si es así, nos vamos

		LDS R22, disp_config // Qué display estamos configurando?
		INC R22 // Pasamos al siguiente display
		STS disp_config, R22 // Guardamos el nuevo valor
	
		CPI R22, 0x04 
		BRNE EXIT_ISR_PCINT0
		CLR R22
		STS disp_config, R22 // Si pasamos de 3, regresamos a 0
		RJMP EXIT_ISR_PCINT0

	EXIT_ISR_PCINT0:
		STS botones, R17 // Guardamos la lectura realizada como nueva lectura de botones
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

		LDI R16, 0x1B
		STS TCNT1H, R16 // Valor inicial H para 60s
		LDI R16, 0x1E
		STS TCNT1L, R16 // Valor inicial L para 60s

		LDS R16, config // Si estamos en modo configuración, no incrementamos el contador de minutos
		CPI R16, 0xFF
		BREQ RETURN_ISR_timer1

		LDS R17, u_minutos // Cargamos el valor de unidades de minuto
		INC R17 // Incrementamos el valor de unidades de minuto
		STS u_minutos, R17 // Guardamos el nuevo valor
		RJMP RETURN_ISR_timer1

	RETURN_ISR_timer1:
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

		LDS R16, config
		CPI R16, 0xFF
		BREQ RETURN_ISR_timer0

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