package com.example.demo.controller;

import com.example.demo.model.WeatherForecast;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

@RestController
public class WeatherForecastController {

    private static final String[] SUMMARIES = {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild",
        "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    @GetMapping("/weatherforecast")
    public List<WeatherForecast> weatherForecast() {
        List<WeatherForecast> forecasts = new ArrayList<>();
        Random random = new Random();

        for (int i = 1; i <= 5; i++) {
            LocalDate date = LocalDate.now().plusDays(i);
            int tempC = random.nextInt(76) - 20;
            forecasts.add(new WeatherForecast(
                date.toString(),
                tempC,
                32 + (tempC * 9 / 5),
                SUMMARIES[random.nextInt(SUMMARIES.length)]
            ));
        }

        return forecasts;
    }
}