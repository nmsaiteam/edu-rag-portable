# ============================================================
# EDU RAG — Demo Startup Script
# Для ноутбука Core i5, 8GB RAM
# ============================================================

param(
    [switch]$SkipModelCheck
)

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  EDU RAG — Запуск демо" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# 1. Проверка Docker
Write-Host "[1/5] Проверка Docker..." -ForegroundColor Yellow
$dockerRunning = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Docker не запущен!" -ForegroundColor Red
    Write-Host "  Запустите Docker Desktop" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "  ✅ Docker работает" -ForegroundColor Green

# 2. Запуск контейнеров
Write-Host ""
Write-Host "[2/5] Запуск контейнеров..." -ForegroundColor Yellow
docker compose -f docker-compose-portable.yml up -d 2>$null

Start-Sleep -Seconds 10

$containers = @("pg-rag", "ollama", "n8n")
foreach ($c in $containers) {
    $status = docker inspect -f '{{.State.Running}}' $c 2>$null
    if ($status -eq "true") {
        Write-Host "  ✅ $c" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $c не запустился" -ForegroundColor Red
    }
}

# 3. Проверка моделей Ollama
if (-not $SkipModelCheck) {
    Write-Host ""
    Write-Host "[3/5] Проверка моделей Ollama..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    $models = docker exec ollama ollama list 2>$null
    
    if ($models -notmatch "nomic-embed-text") {
        Write-Host "  ⏳ Загрузка nomic-embed-text (300 MB)..." -ForegroundColor Yellow
        docker exec ollama ollama pull nomic-embed-text:latest
    }
    Write-Host "  ✅ nomic-embed-text" -ForegroundColor Green
    
    if ($models -notmatch "deepseek-r1:8b") {
        Write-Host "  ⏳ Загрузка deepseek-r1:8b (4.9 GB)..." -ForegroundColor Yellow
        Write-Host "     Модель с reasoning - показывает процесс мышления!" -ForegroundColor Gray
        Write-Host "     Это может занять 10-15 минут..." -ForegroundColor Gray
        docker exec ollama ollama pull deepseek-r1:8b
    }
    Write-Host "  ✅ deepseek-r1:8b (offline LLM с reasoning)" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[3/5] Пропуск проверки моделей (-SkipModelCheck)" -ForegroundColor Gray
}

# 4. Проверка базы данных
Write-Host ""
Write-Host "[4/5] Проверка базы данных..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$count = docker exec pg-rag psql -U rag -d ragdb -t -c "SELECT COUNT(*) FROM rag_chunks;" 2>$null
if ($count) {
    $count = $count.Trim()
    if ([int]$count -gt 0) {
        Write-Host "  ✅ База данных: $count chunks" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  База пустая!" -ForegroundColor Yellow
        Write-Host "     Восстановите: Get-Content ragdb_backup.sql | docker exec -i pg-rag psql -U rag -d ragdb" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Не удалось подключиться к БД" -ForegroundColor Yellow
}

# 5. Проверка n8n
Write-Host ""
Write-Host "[5/5] Проверка n8n..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $response = Invoke-WebRequest -Uri "http://localhost:5678/healthz" -TimeoutSec 10 -UseBasicParsing 2>$null
    Write-Host "  ✅ n8n доступен" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  n8n запускается, подождите 30 сек..." -ForegroundColor Yellow
}

# Итог
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  ГОТОВО!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "  URLs:" -ForegroundColor White
Write-Host "  • n8n:    http://localhost:5678" -ForegroundColor Cyan
Write-Host "  • Ollama: http://localhost:11434" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Тест OFFLINE (локальная LLM):" -ForegroundColor White
Write-Host '  Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body ''{"question": "Ce este metafora?"}'' -ContentType "application/json"' -ForegroundColor Yellow
Write-Host ""
Write-Host "  Тест ONLINE (GPT-5-nano):" -ForegroundColor White
Write-Host '  Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" -Method POST -Body ''{"question": "Ce este metafora?", "llm": "gpt"}'' -ContentType "application/json"' -ForegroundColor Yellow
Write-Host ""
