from fastapi import FastAPI, Query
from datetime import datetime, timedelta
import random
import asyncio

app = FastAPI(title="Python FastAPI Debug Example")


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/debug-test")
async def debug_test(count: int = Query(default=3, ge=1, le=20)):
    items = []

    for i in range(count):
        items.append(f"Item {i + 1}")
        await asyncio.sleep(0.01)

    return {
        "count": count,
        "items": items,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/weatherforecast")
async def weather_forecast():
    summaries = ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"]

    forecasts = []
    for i in range(5):
        date = datetime.utcnow() + timedelta(days=i + 1)
        temp_c = random.randint(-20, 55)
        forecasts.append({
            "date": date.strftime("%Y-%m-%d"),
            "temperatureC": temp_c,
            "temperatureF": 32 + int(temp_c * 9 / 5),
            "summary": random.choice(summaries)
        })

    return forecasts


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)