package com.example.shop;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class InventoryController {

    private static final Logger log = LoggerFactory.getLogger(InventoryController.class);

    // More WARN lines than the log search's 100-line page, so the recipe reads a second page.
    private static final int SUPPLIERS = 120;

    @GetMapping("/inventory/sync")
    String sync() {
        for (int supplier = 1; supplier <= SUPPLIERS; supplier++) {
            log.warn("Supplier {} sync timeout", supplier);
        }
        return "synced";
    }
}
