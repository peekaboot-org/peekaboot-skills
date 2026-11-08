package com.example.shop;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
class OrderController {

    @GetMapping("/orders/{id}")
    String order(@PathVariable long id) {
        throw new IllegalStateException("Order " + id + " has no customer");
    }
}
