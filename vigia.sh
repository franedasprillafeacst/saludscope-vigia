#!/bin/bash
# Revisa cada dirección de sitios.txt (2 intentos, 20 s de espera entre ellos),
# compara con estado.json y avisa SOLO en los cambios (caída / vuelta).
# Las líneas 'cada-hora' solo se revisan si pasaron 55 min desde la última vez
# (modo ahorro: cada visita despierta la app en Laravel Cloud).
set -u
ahora_s=$(date -u +%s)
ultima=$(jq -r '._ultima_revision_apps // 0' estado.json)
toca_apps=$(( ahora_s - ultima >= 3300 ? 1 : 0 ))
nuevo=$(jq '{} + (if ._ultima_revision_apps then {_ultima_revision_apps} else {} end)' estado.json)
[ $toca_apps = 1 ] && nuevo=$(echo "$nuevo" | jq --argjson t "$ahora_s" '. + {_ultima_revision_apps: $t}')
cambios=""
while read -r linea; do
  [[ -z "$linea" || "$linea" == \#* ]] && continue
  url=${linea#cada-hora }
  if [ "$url" != "$linea" ] && [ $toca_apps = 0 ]; then
    nuevo=$(echo "$nuevo" | jq --arg u "$url" --arg e "$(jq -r --arg u "$url" '.[$u] // "arriba"' estado.json)" '. + {($u): $e}')
    continue
  fi
  ok=0
  for intento in 1 2; do
    codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$url" || echo 000)
    if [ "$codigo" -gt 0 ] && [ "$codigo" -lt 500 ]; then ok=1; break; fi
    sleep 20
  done
  antes=$(jq -r --arg u "$url" '.[$u] // "arriba"' estado.json)
  ahora=$([ $ok = 1 ] && echo arriba || echo caida)
  nuevo=$(echo "$nuevo" | jq --arg u "$url" --arg e "$ahora" '. + {($u): $e}')
  if [ "$antes" != "$ahora" ]; then
    if [ "$ahora" = caida ]; then cambios+="🔴 No responde: $url (código $codigo)"$'\n'; else cambios+="🟢 Volvió: $url"$'\n'; fi
  fi
done < sitios.txt
echo "$nuevo" | jq -S . > estado.json

if [ -n "$cambios" ]; then
  texto="Vigilante externo · Saludscope"$'\n'"$cambios"
  echo "$texto"
  if [ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=${texto}" || true
  fi
  if [ -n "${GMAIL_USUARIO:-}" ] && [ -n "${GMAIL_CLAVE:-}" ] && [ -n "${CORREO_DESTINO:-}" ]; then
    { echo "From: Vigilante Saludscope <${GMAIL_USUARIO}>"; echo "To: ${CORREO_DESTINO}"
      echo "Subject: [ALERTA] Vigilante externo Saludscope"; echo "Content-Type: text/plain; charset=UTF-8"; echo; echo "$texto"; } > correo.txt
    curl -s --url 'smtps://smtp.gmail.com:465' --ssl-reqd --mail-from "${GMAIL_USUARIO}" --mail-rcpt "${CORREO_DESTINO}" \
      --user "${GMAIL_USUARIO}:${GMAIL_CLAVE}" -T correo.txt || true
    rm -f correo.txt
  fi
fi
