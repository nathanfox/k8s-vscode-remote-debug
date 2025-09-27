package main

import (
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type HealthResponse struct {
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
}

type DebugTestResponse struct {
	Count     int      `json:"count"`
	Items     []string `json:"items"`
	Timestamp string   `json:"timestamp"`
}

type WeatherForecast struct {
	Date          string `json:"date"`
	TemperatureC  int    `json:"temperatureC"`
	TemperatureF  int    `json:"temperatureF"`
	Summary       string `json:"summary"`
}

func main() {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, HealthResponse{
			Status:    "healthy",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
	})

	r.GET("/debug-test", func(c *gin.Context) {
		countStr := c.DefaultQuery("count", "3")
		count, err := strconv.Atoi(countStr)
		if err != nil || count < 1 || count > 20 {
			count = 3
		}

		items := make([]string, 0, count)
		for i := 0; i < count; i++ {
			items = append(items, "Item "+strconv.Itoa(i+1))
			time.Sleep(10 * time.Millisecond)
		}

		c.JSON(http.StatusOK, DebugTestResponse{
			Count:     count,
			Items:     items,
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
	})

	r.GET("/weatherforecast", func(c *gin.Context) {
		summaries := []string{"Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"}

		forecasts := make([]WeatherForecast, 5)
		for i := 0; i < 5; i++ {
			date := time.Now().UTC().AddDate(0, 0, i+1)
			tempC := rand.Intn(76) - 20
			forecasts[i] = WeatherForecast{
				Date:         date.Format("2006-01-02"),
				TemperatureC: tempC,
				TemperatureF: 32 + (tempC * 9 / 5),
				Summary:      summaries[rand.Intn(len(summaries))],
			}
		}

		c.JSON(http.StatusOK, forecasts)
	})

	r.Run(":8080")
}