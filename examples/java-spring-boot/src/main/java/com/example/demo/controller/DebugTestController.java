package com.example.demo.controller;

import com.example.demo.model.DebugTestResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@RestController
public class DebugTestController {

    @GetMapping("/debug-test")
    public DebugTestResponse debugTest(
            @RequestParam(defaultValue = "3") int count) throws InterruptedException {

        if (count < 1 || count > 20) {
            count = 3;
        }

        List<String> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            items.add("Item " + (i + 1));
            Thread.sleep(10);
        }

        return new DebugTestResponse(
            count,
            items,
            Instant.now().toString()
        );
    }
}