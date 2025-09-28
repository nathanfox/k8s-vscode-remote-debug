use actix_web::{web, App, HttpResponse, HttpServer, Result};
use chrono::{DateTime, Utc, Duration};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::thread;
use std::time::Duration as StdDuration;
use tracing::{info, debug, instrument};
use tracing_subscriber;

#[derive(Serialize, Debug)]
struct HealthResponse {
    status: String,
    timestamp: String,
}

#[derive(Serialize, Debug)]
struct DebugTestResponse {
    count: i32,
    items: Vec<String>,
    timestamp: String,
}

#[derive(Deserialize, Debug)]
struct DebugTestQuery {
    #[serde(default = "default_count")]
    count: i32,
}

fn default_count() -> i32 {
    3
}

#[derive(Serialize, Debug)]
struct WeatherForecast {
    date: String,
    #[serde(rename = "temperatureC")]
    temperature_c: i32,
    #[serde(rename = "temperatureF")]
    temperature_f: i32,
    summary: String,
}

#[instrument]
async fn health() -> Result<HttpResponse> {
    info!("Health check called");
    let response = HealthResponse {
        status: "healthy".to_string(),
        timestamp: Utc::now().to_rfc3339(),
    };
    debug!("Health response: {:?}", response.status);
    Ok(HttpResponse::Ok().json(response))
}

#[instrument]
async fn debug_test(query: web::Query<DebugTestQuery>) -> Result<HttpResponse> {
    info!("Debug test called with count={}", query.count);
    let mut items = Vec::new();

    for i in 0..query.count {
        debug!("Processing item {}/{}", i + 1, query.count);
        let item = format!("Item {}", i + 1);
        items.push(item);
        thread::sleep(StdDuration::from_millis(10));
    }

    let response = DebugTestResponse {
        count: query.count,
        items,
        timestamp: Utc::now().to_rfc3339(),
    };
    info!("Debug test completed, returning {} items", response.count);
    Ok(HttpResponse::Ok().json(response))
}

#[instrument]
async fn weather_forecast() -> Result<HttpResponse> {
    info!("Weather forecast called");
    let summaries = vec![
        "Freezing", "Bracing", "Chilly", "Cool", "Mild",
        "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    ];

    let mut rng = rand::thread_rng();
    let mut forecasts = Vec::new();

    for i in 1..=5 {
        let date: DateTime<Utc> = Utc::now() + Duration::days(i);
        let temp_c = rng.gen_range(-20..55);
        let temp_f = 32 + (temp_c * 9 / 5);
        let summary_index = rng.gen_range(0..summaries.len());
        debug!("Generated forecast for day {}: {}°C ({})", i, temp_c, summaries[summary_index]);

        forecasts.push(WeatherForecast {
            date: date.format("%Y-%m-%d").to_string(),
            temperature_c: temp_c,
            temperature_f: temp_f,
            summary: summaries[summary_index].to_string(),
        });
    }
    info!("Weather forecast completed, returning {} days", forecasts.len());
    Ok(HttpResponse::Ok().json(forecasts))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("debug")
        .init();

    info!("Starting Rust Actix-web server on 0.0.0.0:8080");

    HttpServer::new(|| {
        App::new()
            .route("/health", web::get().to(health))
            .route("/debug-test", web::get().to(debug_test))
            .route("/weatherforecast", web::get().to(weather_forecast))
    })
    .workers(1)
    .bind("0.0.0.0:8080")?
    .run()
    .await
}