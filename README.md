# Vigilante externo · Saludscope

Revisa cada 10 minutos (las apps, una vez por hora), **desde fuera de Laravel Cloud**, que las apps de la
suite Saludscope respondan (lista en `sitios.txt`). Si una deja de responder
dos veces seguidas, o vuelve, avisa por Telegram y correo (secretos del repo:
`TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID`, `GMAIL_USUARIO`, `GMAIL_CLAVE`,
`CORREO_DESTINO`). Solo avisa en los cambios; el último estado conocido está
en `estado.json`.

Complementa las alertas de Mando (mando.saludscope.com): si se cae Laravel
Cloud entero, Mando no puede avisar, este vigilante sí.
