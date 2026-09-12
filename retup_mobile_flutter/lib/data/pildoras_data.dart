enum EstadoPildora {
  completada,
  enCurso,
  bloqueada,
}

class Pildora {
  final int id;
  final int numero;
  final String titulo;
  final String emoji;
  final String habilidadClave;
  final int retoId;
  final List<String> seccionesContenido;
  final List<String> opcionesRespuesta;
  EstadoPildora estado;
  bool completada;

  Pildora({
    required this.id,
    required this.numero,
    required this.titulo,
    required this.emoji,
    required this.habilidadClave,
    required this.retoId,
    required this.seccionesContenido,
    required this.opcionesRespuesta,
    required this.estado,
    this.completada = false,
  });
}

final List<Pildora> pildorasData = [
  Pildora(
    id: 1,
    numero: 1,
    titulo: 'Mensaje en una frase',
    emoji: '🎯',
    habilidadClave: 'Ir al grano',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      '🎯 Mensaje en una frase\n\n"Menos es más. Hoy tu palabra vale oro 💬"',
      'El Discurso de Gettysburg (1863), uno de los textos más citados de la historia, tiene solo 272 palabras y duró poco más de 2 minutos. El orador anterior habló 2 horas... y nadie lo recuerda.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de ir al grano? Es 100% anónimo, tú solo eliges 😉\n\n[Se despliega dinámicamente la lista de colaboradores de la empresa. Fuente de datos pendiente de definir con Ceci: ¿directorio HR / nómina de la app?]',
      'Recibimos en promedio 120+ correos al día. Un mensaje directo se lee; uno largo se archiva para "luego" (y ese luego nunca llega) 📬',
      'Del 1 al 5, ¿qué tan claro/a eres cuando explicas una idea? 🪞',
      'Hoy aprendiste que una idea clara en 1 frase pesa más que un párrafo entero. Menos palabras, más impacto.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de ir al grano? Anónimo total, nadie lo va a saber 🤐\n\n[Se despliega dinámicamente la lista de colaboradores de la empresa. Fuente de datos pendiente de definir con Ceci: ¿directorio HR / nómina de la app?]',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto:\n\n『 Mi reto de hoy es "🎯 Mensaje en una frase". Te he elegido para hacerlo juntos. ¿Te apuntas? 』\n\n[ ENVIAR MENSAJE ]  (se envía automático dentro de la app; quien lo recibe puede responder con ❤️ o 👍)',
      '¡Lo lograste! 🎉 Un pasito más hacia ir al grano como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 2,
    numero: 2,
    titulo: 'Escucha activa en 3 pasos',
    emoji: '👂',
    habilidadClave: 'Escuchar de verdad',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      // Sección 1: Bienvenida + frase motivante
      'Escuchar no es esperar tu turno para hablar 😉',

      // Sección 2: Dato/evento histórico (gancho)
      'En 1957, los psicólogos Carl Rogers y Richard Farson acuñaron el término "escucha activa": prestar atención total, sin juzgar ni interrumpir, para entender de verdad al otro.',

      // Sección 3: Pregunta anónima - ¿quién lo hace mejor?
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de escuchar de verdad? Es 100% anónimo, tú solo eliges 😉',

      // Sección 4: Por qué importa (dato estadístico)
      'Solemos recordar solo entre el 25% y el 50% de lo que escuchamos. O sea, la mitad de esa reunión... se te escapó 🙈',

      // Sección 5: Autopercepción (escala 1-5)
      'Del 1 al 5, ¿qué tan seguido dejas terminar la idea antes de responder? 🪞',

      // Sección 6: Qué aprendiste + beneficio
      'Escuchar bien no es quedarte callado/a: es entender, resumir y preguntar. Así se construye confianza real.',

      // Sección 7: Pregunta anónima - ¿quién podría mejorar?
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de escuchar de verdad? Anónimo total, nadie lo va a saber 🤐',

      // Sección 8: Práctica social con un compañero
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Escucha activa en 3 pasos. Te he elegido para hacerlo juntos. ¿Te apuntas?"',

      // Sección 9: Mensaje de cierre gratificante
      '¡Lo lograste! 🎉 Un pasito más hacia escuchar de verdad como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 3,
    numero: 3,
    titulo: 'El silencio también comunica',
    emoji: '🤐',
    habilidadClave: 'Manejar los silencios',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      // Sección 1: Bienvenida + frase motivante
      'A veces la mejor respuesta es... nada 🤐',

      // Sección 2: Dato/evento histórico (gancho)
      'Un estudio de la Universidad de Groningen encontró que un silencio de apenas 4 segundos en una conversación ya se siente incómodo, como un mini rechazo social.',

      // Sección 3: Pregunta anónima - ¿quién lo hace mejor?
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de manejar los silencios? Es 100% anónimo, tú solo eliges 😉',

      // Sección 4: Por qué importa (dato estadístico)
      'Ese "silencio incómodo" activa las mismas zonas cerebrales que el dolor social. Por eso llenamos huecos hablando de más 🧠',

      // Sección 5: Autopercepción (escala 1-5)
      'Del 1 al 5, ¿qué tan cómodo/a te sientes con un silencio en la conversación? 🪞',

      // Sección 6: Qué aprendiste + beneficio
      'Un silencio bien puesto da espacio para pensar y muestra seguridad. No todo hueco hay que llenarlo.',

      // Sección 7: Pregunta anónima - ¿quién podría mejorar?
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de manejar los silencios? Anónimo total, nadie lo va a saber 🤐',

      // Sección 8: Práctica social con un compañero
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es El silencio también comunica. Te he elegido para hacerlo juntos. ¿Te apuntas?"',

      // Sección 9: Mensaje de cierre gratificante
      '¡Lo lograste! 🎉 Un pasito más hacia manejar los silencios como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 4,
    numero: 4,
    titulo: 'Cuerpo que habla',
    emoji: '🕺',
    habilidadClave: 'Comunicar con el cuerpo',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      // Sección 1: Bienvenida + frase motivante
      'Tu cara ya dijo lo que ibas a decir 😄',

      // Sección 2: Dato/evento histórico (gancho)
      'En 1967, Albert Mehrabian (UCLA) publicó su famosa regla 7-38-55: en mensajes sobre sentimientos y actitudes, el 55% del impacto viene del lenguaje corporal, 38% del tono, y solo 7% de las palabras.',

      // Sección 3: Pregunta anónima - ¿quién lo hace mejor?
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de comunicar con el cuerpo? Es 100% anónimo, tú solo eliges 😉',

      // Sección 4: Por qué importa (dato estadístico)
      'Ojo: esa regla aplica solo cuando el tono y el cuerpo contradicen las palabras. Aun así, deja claro que el "cómo" pesa muchísimo 📊',

      // Sección 5: Autopercepción (escala 1-5)
      'Del 1 al 5, ¿qué tan consciente eres de tu lenguaje corporal al hablar? 🪞',

      // Sección 6: Qué aprendiste + beneficio
      'Brazos cruzados, mirada esquiva o postura cerrada hablan antes que tú. Cuida el cuerpo tanto como el mensaje.',

      // Sección 7: Pregunta anónima - ¿quién podría mejorar?
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de comunicar con el cuerpo? Anónimo total, nadie lo va a saber 🤐',

      // Sección 8: Práctica social con un compañero
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Cuerpo que habla. Te he elegido para hacerlo juntos. ¿Te apuntas?"',

      // Sección 9: Mensaje de cierre gratificante
      '¡Lo lograste! 🎉 Un pasito más hacia comunicar con el cuerpo como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 5,
    numero: 5,
    titulo: 'Feedback sandwich',
    emoji: '🥪',
    habilidadClave: 'Dar feedback',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Un buen feedback no duele, construye 🛠️',
      'La técnica del "feedback sándwich" (algo positivo, la mejora, y otro positivo) se popularizó en 1982 con el libro "The One Minute Manager" de Blanchard y Johnson.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de dar feedback? Es 100% anónimo, tú solo eliges 😉',
      'Los equipos que reciben feedback frecuente y bien dado muestran niveles de compromiso notablemente más altos que los que casi no lo reciben.',
      'Del 1 al 5, ¿qué tan cómodo/a te sientes dando feedback a un compañero? 🪞',
      'El feedback bien dado no es criticar: es ayudar a mejorar sin bajarle el ánimo a nadie.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de dar feedback? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Feedback sándwich. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia dar feedback como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 6,
    numero: 6,
    titulo: 'Pregunta abierta',
    emoji: '❓',
    habilidadClave: 'Hacer preguntas abiertas',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Las mejores conversaciones empiezan con un "¿cómo...?" 🔍',
      'En 1984, un estudio de Beckman y Frankel reveló que los médicos interrumpían a sus pacientes, en promedio, a los 18 segundos de empezar a hablar. Spoiler: se perdían información clave.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de hacer preguntas abiertas? Es 100% anónimo, tú solo eliges 😉',
      'El método socrático (puras preguntas abiertas, sin dar la respuesta) lleva más de 2.400 años usándose para hacer pensar en vez de solo informar 🏛️',
      'Del 1 al 5, ¿qué tan seguido usas preguntas abiertas en vez de cerradas? 🪞',
      'Una pregunta abierta ("¿qué opinas?") abre más la conversación que una cerrada ("¿estás de acuerdo?").',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de hacer preguntas abiertas? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Pregunta abierta. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia hacer preguntas abiertas como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 7,
    numero: 7,
    titulo: 'Email en 3 líneas',
    emoji: '📧',
    habilidadClave: 'Escribir mensajes cortos',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Si tu email necesita scroll, algo falló 📜',
      'En el siglo XIX, Western Union cobraba por palabra en los telegramas. La gente aprendió a decir mucho con poquísimo texto. Netflix, LOL y OK nacieron de esa lógica de ahorro.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de escribir mensajes cortos? Es 100% anónimo, tú solo eliges 😉',
      'Un trabajador de oficina dedica cerca del 28% de su semana laboral solo a leer y responder correos. Eso son más de 11 horas semanales 📧',
      'Del 1 al 5, ¿qué tan cortos y claros son tus mensajes escritos? 🪞',
      'Un mensaje corto y claro se lee entero. Uno largo se guarda para "después" (y ya sabes cómo termina eso).',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de escribir mensajes cortos? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Email en 3 líneas. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia escribir mensajes cortos como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 8,
    numero: 8,
    titulo: 'Resumen de reunión',
    emoji: '📋',
    habilidadClave: 'Cerrar reuniones con resumen',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Una reunión sin resumen es una reunión que nunca pasó 🌀',
      'Un estudio publicado en Harvard Business Review encontró que los altos ejecutivos pasan más de 23 horas a la semana en reuniones, muchas de ellas sin conclusiones claras ni seguimiento.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de cerrar reuniones con resumen? Es 100% anónimo, tú solo eliges 😉',
      'Cerrar con un resumen de "quién hace qué y para cuándo" es de los hábitos más simples para que una reunión sí tenga resultados 📌',
      'Del 1 al 5, ¿qué tan seguido cierras una reunión con próximos pasos claros? 🪞',
      '30 segundos de resumen al final ahorran horas de confusión después. Siempre cierra con próximos pasos.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de cerrar reuniones con resumen? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Resumen de reunión. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia cerrar reuniones con resumen como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 9,
    numero: 9,
    titulo: 'Tono adecuado',
    emoji: '🎵',
    habilidadClave: 'Ajustar el tono según la situación',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'El mismo mensaje, dicho distinto, cambia todo 🎭',
      'En 1974, el psicólogo Mark Snyder (Univ. de Minnesota) definió la "auto-monitorización": la capacidad de leer una situación social y ajustar tu comportamiento y tono a ella.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de ajustar el tono según la situación? Es 100% anónimo, tú solo eliges 😉',
      'Las personas con alta auto-monitorización ajustan tono, ritmo y formalidad según el contexto, y eso se asocia a mejores relaciones laborales.',
      'Del 1 al 5, ¿qué tan bien adaptas tu tono según con quién hablas? 🪞',
      'No es hipocresía, es adaptación: el mismo mensaje serio en una crisis y relajado en un café suena distinto, y está bien.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de ajustar el tono según la situación? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Tono adecuado. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia ajustar el tono según la situación como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 10,
    numero: 10,
    titulo: 'Contacto visual',
    emoji: '👁️',
    habilidadClave: 'Sostener la mirada',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Los ojos también dan feedback 👁️',
      'En 2021, el investigador Jeremy Bailenson (Stanford) publicó el estudio que bautizó el "Zoom Fatigue": mirar caras en primer plano durante videollamadas todo el día agota al cerebro más de lo normal.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de sostener la mirada? Es 100% anónimo, tú solo eliges 😉',
      'En videollamadas grupales, tendemos a mirar el propio recuadro más que a la persona que habla. Un mal hábito para conectar de verdad 📷',
      'Del 1 al 5, ¿qué tan cómodo/a te sientes sosteniendo la mirada al hablar? 🪞',
      'El contacto visual (real o en cámara) transmite atención y confianza. Sin exagerar: no es un duelo de miradas.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de sostener la mirada? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Contacto visual. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia sostener la mirada como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 11,
    numero: 11,
    titulo: 'Parafraseo exprés',
    emoji: '🔄',
    habilidadClave: 'Parafrasear al otro',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Repetir con tus palabras es la prueba de que sí escuchaste 🔄',
      'Chris Voss, ex negociador de rehenes del FBI, popularizó el "mirroring": repetir las últimas palabras clave del otro para generar confianza y ganar tiempo para pensar.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de parafrasear al otro? Es 100% anónimo, tú solo eliges 😉',
      'Voss documentó cómo esta técnica, usada en negociaciones de alto riesgo, se traduce directo al día a día: reuniones, ventas, hasta discusiones de pareja.',
      'Del 1 al 5, ¿qué tan seguido confirmas que entendiste antes de responder? 🪞',
      'Parafrasear ("o sea, lo que dices es...") demuestra que escuchaste y evita malentendidos antes de que crezcan.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de parafrasear al otro? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Parafraseo exprés. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia parafrasear al otro como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 12,
    numero: 12,
    titulo: 'Cero muletillas',
    emoji: '🚫',
    habilidadClave: 'Hablar sin muletillas',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Eeeh... hoy toca hablar sin "eeeh" 😅',
      'En 1924, Ralph C. Smedley fundó Toastmasters International, un club pensado para ayudar a la gente a hablar en público con más claridad y menos muletillas.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de hablar sin muletillas? Es 100% anónimo, tú solo eliges 😉',
      'Un truco que usan ahí: sustituir el "eh" o "o sea" por una pausa de silencio. Suena más seguro y profesional al instante 🎤',
      'Del 1 al 5, ¿qué tan seguido usas muletillas al hablar? 🪞',
      'Una pausa vale más que una muletilla. Callarte 1 segundo transmite más control del que crees.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de hablar sin muletillas? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Cero muletillas. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia hablar sin muletillas como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 13,
    numero: 13,
    titulo: 'Mensaje sin jerga',
    emoji: '➖',
    habilidadClave: 'Evitar la jerga técnica',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Si tu abuela no lo entiende, simplifícalo 👵',
      'En 2010, EE.UU. aprobó la "Plain Writing Act": una ley que obliga a las agencias del gobierno a comunicarse en lenguaje claro, sin jerga innecesaria, para que cualquier ciudadano entienda.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de evitar la jerga técnica? Es 100% anónimo, tú solo eliges 😉',
      'El lenguaje claro no es "hablar fácil": es eliminar la jerga que solo entienden 3 personas en la sala, para que el mensaje llegue a todos 🗣️',
      'Del 1 al 5, ¿qué tan seguido evitas la jerga técnica al explicar algo? 🪞',
      'La jerga puede sonar experta, pero si nadie entiende, el mensaje no sirvió de nada. Claridad ante todo.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de evitar la jerga técnica? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Mensaje sin jerga. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia evitar la jerga técnica como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 14,
    numero: 14,
    titulo: 'Storytelling breve',
    emoji: '📚',
    habilidadClave: 'Contar historias cortas',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Un buen dato se olvida. Una buena historia, no 📚',
      'Las fábulas de Esopo, del siglo VI a.C., llevan más de 2.500 años transmitiendo lecciones... con solo un cuento corto y un animal parlante.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de contar historias cortas? Es 100% anónimo, tú solo eliges 😉',
      'Investigaciones de Jennifer Aaker (Stanford GSB) muestran que las historias se recuerdan muchísimo mejor que los datos sueltos y aislados.',
      'Del 1 al 5, ¿qué tan seguido usas un ejemplo o historia para explicar algo? 🪞',
      'No necesitas ser Esopo: una mini-historia real de 30 segundos vende una idea mejor que 10 datos sueltos.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de contar historias cortas? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Storytelling breve. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia contar historias cortas como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 15,
    numero: 15,
    titulo: 'Pregunta de cierre',
    emoji: '❓',
    habilidadClave: 'Cerrar con una pregunta',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'No cierres la puerta, déjala entreabierta 🚪',
      'Dale Carnegie, en su clásico "Cómo ganar amigos e influir sobre las personas" (1936), insistía en cerrar conversaciones dejando al otro con espacio para opinar, no con un punto final seco.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de cerrar con una pregunta? Es 100% anónimo, tú solo eliges 😉',
      'El libro de Carnegie ha vendido más de 30 millones de copias desde 1936: la idea de cerrar bien una conversación sigue vigente casi 90 años después 📘',
      'Del 1 al 5, ¿qué tan seguido cierras tus conversaciones con una pregunta? 🪞',
      'Terminar con "¿qué opinas tú?" en vez de solo "listo, ya está" mantiene la conversación (y la relación) abierta.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de cerrar con una pregunta? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Pregunta de cierre. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia cerrar con una pregunta como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 16,
    numero: 16,
    titulo: 'Comunicación asertiva',
    emoji: '💪',
    habilidadClave: 'Ser asertivo/a',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Decir "no" también es comunicar bien 🙌',
      'En 1970, Robert Alberti y Michael Emmons publicaron "Your Perfect Right", el libro que popularizó el entrenamiento asertivo: decir lo que piensas sin pisar al otro ni dejarte pisar.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de ser asertivo/a? Es 100% anónimo, tú solo eliges 😉',
      'Su modelo distingue 3 estilos: pasivo, agresivo y asertivo. El asertivo es el único que defiende tus intereses sin dañar la relación.',
      'Del 1 al 5, ¿qué tan fácil te resulta decir "no" cuando lo necesitas? 🪞',
      'Ser asertivo/a no es ser borde: es decir las cosas claras, con respeto, sin quedarte callado/a ni explotar.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de ser asertivo/a? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Comunicación asertiva. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia ser asertivo/a como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 17,
    numero: 17,
    titulo: 'Lectura de sala',
    emoji: '👀',
    habilidadClave: 'Leer el ambiente',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Antes de hablar, siente la sala 🌡️',
      'En 2001, Simon Baron-Cohen (Univ. de Cambridge) creó el test "Reading the Mind in the Eyes": evaluar emociones ajenas solo mirando los ojos de una persona.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de leer el ambiente? Es 100% anónimo, tú solo eliges 😉',
      'Su investigación mostró que esta habilidad varía muchísimo entre personas... pero se puede entrenar prestando más atención a gestos y silencios.',
      'Del 1 al 5, ¿qué tan bien detectas el ambiente antes de comunicar algo importante? 🪞',
      'Leer la sala (tensión, aburrimiento, entusiasmo) antes de hablar te permite ajustar el mensaje a tiempo.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de leer el ambiente? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Lectura de sala. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia leer el ambiente como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 18,
    numero: 18,
    titulo: 'Un mensaje, un canal',
    emoji: '📱',
    habilidadClave: 'Elegir bien el canal',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'No todo se dice por WhatsApp 📱',
      'En 1986, Richard Daft y Robert Lengel propusieron la "Teoría de la Riqueza de los Medios": cada canal (cara a cara, llamada, email, chat) transmite distinta cantidad de matices y emoción.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de elegir bien el canal? Es 100% anónimo, tú solo eliges 😉',
      'Según su modelo, temas ambiguos o delicados necesitan canales "ricos" (cara a cara o videollamada); temas simples funcionan bien por escrito.',
      'Del 1 al 5, ¿qué tan bien eliges el canal correcto según el mensaje? 🪞',
      'Un mensaje delicado por chat se puede malinterpretar fácil. Elegir bien el canal evita líos innecesarios.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de elegir bien el canal? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Un mensaje, un canal. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia elegir bien el canal como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 19,
    numero: 19,
    titulo: 'Feedback recibido',
    emoji: '💬',
    habilidadClave: 'Recibir feedback',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Que te den feedback no es un ataque, es un regalo 🎁',
      'La psicóloga Carol Dweck (Stanford) desarrolló el concepto de "mentalidad de crecimiento": quienes ven el feedback como una oportunidad de mejorar, no como una amenaza, avanzan más rápido.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de recibir feedback? Es 100% anónimo, tú solo eliges 😉',
      'Su investigación muestra que la forma en que interpretamos una crítica (amenaza vs. oportunidad) cambia directamente cómo actuamos después de recibirla.',
      'Del 1 al 5, ¿qué tan bien recibes una crítica constructiva sin ponerte a la defensiva? 🪞',
      'Recibir feedback sin ponerte a la defensiva es una habilidad en sí misma. Respira, escucha, y luego decide qué hacer con eso.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de recibir feedback? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Feedback recibido. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia recibir feedback como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
  Pildora(
    id: 20,
    numero: 20,
    titulo: 'Presentación de 60 seg',
    emoji: '⏱️',
    habilidadClave: 'Presentarte en 60 segundos',
    retoId: 1,
    estado: EstadoPildora.enCurso,
    completada: false,
    seccionesContenido: [
      'Si tuvieras 60 segundos en un ascensor, ¿qué dirías? 🛗',
      'El "elevator pitch" nació en la cultura de negocios de EE.UU. en los años 80: la idea de vender un proyecto en el tiempo que dura un viaje en ascensor con alguien importante.',
      'Antes de seguir... 🤫 ¿Quién del equipo crees que se le da mejor eso de presentarte en 60 segundos? Es 100% anónimo, tú solo eliges 😉',
      'La lógica detrás sigue vigente en pitches de startups, entrevistas y networking: si no puedes resumir tu idea en 1 minuto, probablemente aún no está clara ni para ti.',
      'Del 1 al 5, ¿qué tan seguro/a te sientes presentándote en menos de 1 minuto? 🪞',
      'Cerraste el Reto 1: hoy practicaste resumir quién eres y qué haces en 60 segundos, sin perder lo esencial.',
      'Va otra pregunta, con cariño 💛 ¿Quién crees que podría currarse un poco más lo de presentarte en 60 segundos? Anónimo total, nadie lo va a saber 🤐',
      'Es hora de ponerlo en práctica con alguien de confianza 🙌 Elige 1 o 2 compañeros y mándales este reto: "Mi reto de hoy es Presentación de 60 seg. Te he elegido para hacerlo juntos. ¿Te apuntas?"',
      '¡Lo lograste! 🎉 Un pasito más hacia presentarte en 60 segundos como un/a crack. Nos vemos mañana con una píldora nueva 👋'
    ],
    opcionesRespuesta: ['Opción 1', 'Opción 2', 'Opción 3'],
  ),
];
