package com.example.demo.model;

import java.util.List;

public class DebugTestResponse {
    private int count;
    private List<String> items;
    private String timestamp;

    public DebugTestResponse() {
    }

    public DebugTestResponse(int count, List<String> items, String timestamp) {
        this.count = count;
        this.items = items;
        this.timestamp = timestamp;
    }

    public int getCount() {
        return count;
    }

    public void setCount(int count) {
        this.count = count;
    }

    public List<String> getItems() {
        return items;
    }

    public void setItems(List<String> items) {
        this.items = items;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }
}