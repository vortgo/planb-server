#!/usr/bin/env python3
"""
Plan B — Discord Server Info via Webhook
Использование:
  python3 send_server_info.py WEBHOOK_URL              # создать новое сообщение
  python3 send_server_info.py WEBHOOK_URL MESSAGE_ID   # отредактировать существующее
"""

import json, sys, requests

WEBHOOK_URL = sys.argv[1] if len(sys.argv) > 1 else None
MESSAGE_ID = sys.argv[2] if len(sys.argv) > 2 else None

if not WEBHOOK_URL:
    print("Ошибка: укажи webhook URL как аргумент")
    print("python3 send_server_info.py https://discord.com/api/webhooks/...")
    sys.exit(1)

pad = '\u2800' * 45
padwide = '\u2800' * 80

data = {
    'username': 'Plan B',
    'embeds': [
        {
            'color': 1941109,
            'author': {'name': 'О  С Е Р В Е Р Е'},
            'description': (
                'Хардкорный PvP-сервер с кастомными ивентами, токсичными зонами и уникальным контентом.\n'
                'Здесь нет правил, которые защищают тебя от других игроков — есть только твои навыки и твой Plan B.\n\n'
                '```ansi\n'
                '\u001b[0;33mРЕЖИМ\u001b[0m              \u001b[0;33mСЛОТОВ\u001b[0m\n'
                '\u001b[1;37mPvP Hardcore\u001b[0m        \u001b[1;37m32\u001b[0m\n\n'
                '\u001b[0;33mВАЙП\u001b[0m               \u001b[0;33mРЕСТАРТЫ\u001b[0m\n'
                '\u001b[1;37m1-2 месяца\u001b[0m         \u001b[1;37mКаждые 8ч\u001b[0m\n'
                '```' + pad
            )
        },
        {
            'color': 1941109,
            'author': {'name': 'С Т А Р Т  И Г Р Ы'},
            'description': (
                '📻 При спавне получаешь рацию — слушай радио-ивенты\n\n'
                '📝 В инвентаре записка с координатами сейфзоны\n\n'
                '🎒 В сейфзоне — стартовый эквип для новичков\n\n'
                '📚 Библиотека с книгами 1 лвл — прокачайся перед выходом' + pad
            )
        },
        {
            'color': 15227196,
            'author': {'name': 'Ф И Ч И  С Е Р В Е Р А'},
            'description': (
                '⚔️ Вся карта — PvP, кроме сейфзоны\n\n'
                '☢️ Луисвиль накрыт газом — нужен противогаз\n\n'
                '📻 Автоматические радио-ивенты с уникальным лутом\n\n'
                '⛽ Бензин только в сейфзоне — планируй вылазки\n\n'
                '💎 Мало лута — каждая находка на вес золота' + pad
            )
        },
        {
            'color': 13379894,
            'author': {'name': '☢️  Л У И С В И Л Ь  —  З О Н А  З А Р А Ж Е Н И Я'},
            'description': (
                'Самая богатая зона на карте накрыта токсичным газом. Без противогаза — смерть.\n'
                'Лучший лут, но и самый высокий риск. Добудь хазмат-снаряжение, прежде чем соваться.' + pad
            )
        },
        {
            'color': 7506394,
            'author': {'name': 'К А К  П О Д К Л Ю Ч И Т Ь С Я'},
            'description': (
                '**1.** Project Zomboid → Сетевая игра\n\n'
                '**2.** Добавь сервер:\n'
                '```\n185.195.27.99:16261\n```\n'
                '**3.** Моды установятся автоматически\n\n'
                '**4.** Выживай. Или нет.\n' + pad
            )
        },
        {
            'color': 5592405,
            'description': (
                'Вопросы → <#1487802872702701620>\n'
                'Баги → <#1487804471940481204>\n'
                'Правила → <#1487802864284729424>\n' + padwide
            )
        }
    ]
}

if MESSAGE_ID:
    r = requests.patch(f'{WEBHOOK_URL}/messages/{MESSAGE_ID}', json=data)
    print(f'Edited: {r.status_code}')
else:
    r = requests.post(WEBHOOK_URL, json=data)
    resp = r.json()
    print(f'Created: {r.status_code}, message_id: {resp.get("id", "?")}')

# Текущий webhook: https://discord.com/api/webhooks/1487833231398273057/XiDgHDS115RNFSgWfB-PQ5Bm8RGmGtDCAZTOGynlQOnZDgwVFmiPY-urzC1iOI5tOjBb
# Текущий message_id: 1487833645455638780