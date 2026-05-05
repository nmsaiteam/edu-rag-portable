# EDU RAG — Demo Setup (Online + Offline)

## Архитектура

```
┌──────────────────────────────────────────────────────────────┐
│                    Ноутбук (Core i5, 8GB)                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   PostgreSQL + pgvector ─────────────────┐                   │
│        (11520 chunks)                    │                   │
│                                          ↓                   │
│   Ollama ──┬── nomic-embed-text ──→ Embeddings               │
│            │                                                 │
│            └── deepseek-r1:8b ──→ OFFLINE генерация (с reasoning) │
│                                                              │
│   n8n ───────────────────→ Workflow                          │
│            │                                                 │
│            └── OpenAI API ──→ ONLINE генерация (GPT-5-nano)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Режимы работы

| Режим | LLM | Интернет | Скорость | Качество |
|-------|-----|----------|----------|----------|
| **OFFLINE** | deepseek-r1:8b | ❌ Не нужен | 15-30 сек | ⭐⭐⭐⭐⭐ |
| **ONLINE** | GPT-5-nano | ✅ Нужен | 2-5 сек | ⭐⭐⭐⭐ |

---

## Файлы для переноса

Скопируйте на флешку папку `edu-rag-portable/`:

```
edu-rag-portable/
├── docker-compose-portable.yml  # Docker конфигурация
├── workflow_portable.json       # n8n workflow (online + offline)
├── ragdb_backup.sql             # База данных (11520 chunks)
├── start_demo.ps1               # Скрипт запуска
└── DEMO_SETUP.md                # Эта инструкция
```

---

## Первая установка на ноутбуке

### 1. Установите Docker Desktop
https://www.docker.com/products/docker-desktop/

**Важно:** В настройках Docker Desktop → Resources → Memory: **минимум 6 GB**

### 2. Скопируйте файлы
```powershell
mkdir C:\edu-rag-demo
# Скопируйте все файлы в эту папку
```

### 3. Запустите скрипт
```powershell
cd C:\edu-rag-demo
.\start_demo.ps1
```

Первый запуск займёт 10-15 минут (скачивание образов и моделей).

### 4. Восстановите базу данных
```powershell
Get-Content ragdb_backup.sql | docker exec -i pg-rag psql -U rag -d ragdb
```

### 5. Настройте n8n
1. Откройте http://localhost:5678
2. Создайте аккаунт
3. **Settings** → **Credentials** → добавьте:
   - **PostgreSQL**: Host=`pg-rag`, Port=`5432`, DB=`ragdb`, User=`rag`, Pass=`ragpass123`
   - **OpenAI API**: ваш API ключ (для online режима)
4. **Import workflow**: `workflow_portable.json`
5. Настройте credentials в узлах
6. **Activate** workflow

---

## Запуск демо (после настройки)

```powershell
cd C:\edu-rag-demo
.\start_demo.ps1 -SkipModelCheck
```

---

## Использование

### OFFLINE режим (без интернета)
```powershell
$result = Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body '{"question": "Ce este metafora?"}' -ContentType "application/json"
$result.answer
$result.llm  # → deepseek-r1:8b
```

### ONLINE режим (с интернетом)
```powershell
$result = Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body '{"question": "Ce este metafora?", "llm": "gpt"}' -ContentType "application/json"
$result.answer
$result.llm  # → gpt-5-nano
```

### С фильтром по предмету
```powershell
# Биология
$body = '{"question": "Ce este celula?", "subject": "biology"}'

# История, 10 класс
$body = '{"question": "Cine a fost Stefan cel Mare?", "subject": "history", "grade": 10}'

Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body $body -ContentType "application/json"
```

---

## Требования к ресурсам

| Компонент | RAM | Диск |
|-----------|-----|------|
| PostgreSQL | 500 MB | 500 MB |
| Ollama + модели | 5-6 GB | 5.5 GB |
| n8n | 200 MB | 200 MB |
| **Итого** | **~6-7 GB** | **~6.5 GB** |

---

## Демонстрация для жюри

### Сценарий 1: Показать оба режима

```powershell
# 1. Offline режим
Write-Host "OFFLINE режим (deepseek-r1:8b с reasoning):"
$offline = Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body '{"question": "Ce este fotosinteza?"}' -ContentType "application/json"
$offline.answer
$offline.llm

# 2. Online режим
Write-Host "`nONLINE режим (GPT-5-nano):"
$online = Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body '{"question": "Ce este fotosinteza?", "llm": "gpt"}' -ContentType "application/json"
$online.answer
$online.llm
```

### Сценарий 2: Мультиязычность

```powershell
# Румынский
Invoke-RestMethod ... -Body '{"question": "Ce este metafora?"}'

# Русский
Invoke-RestMethod ... -Body '{"question": "Что такое метафора?"}'

# English
Invoke-RestMethod ... -Body '{"question": "What is photosynthesis?"}'
```

### Сценарий 3: Разные предметы

```powershell
# Литература
'{"question": "Ce este metafora?", "subject": "romanian"}'

# Биология
'{"question": "Ce este celula?", "subject": "biology"}'

# История
'{"question": "Cine a fost Stefan cel Mare?", "subject": "history"}'
```

---

## Troubleshooting

### Ollama медленно отвечает
Первый запрос после старта загружает модель в RAM (~30 сек). Последующие быстрее.

### n8n ошибка timeout
Увеличьте timeout в узле "8b. Ollama Local" до 300000 (5 минут).

### Недостаточно памяти
Закройте браузер и другие приложения. Нужно ~6 GB свободной RAM.

### Offline не работает без интернета
Убедитесь что модели скачаны заранее:
```powershell
docker exec ollama ollama list
# Должны быть: nomic-embed-text:latest, deepseek-r1:8b
```

---

## Остановка

```powershell
docker compose -f docker-compose-portable.yml down
```
