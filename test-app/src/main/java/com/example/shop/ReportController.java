package com.example.shop;

import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class ReportController {

    // Above Peekaboot's 1000 ms slow-trace threshold, so the route gets a slow trace.
    private static final Duration MONTHLY_REPORT_TIME = Duration.ofMillis(1100);

    @GetMapping("/reports/monthly")
    String monthly() throws InterruptedException {
        Thread.sleep(MONTHLY_REPORT_TIME);
        return "monthly report";
    }
}
