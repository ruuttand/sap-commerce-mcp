package com.example.test;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.beans.factory.annotation.Qualifier;

@RequestMapping(
    value = "/api/products",
    method = RequestMethod.GET,
    produces = "application/json"
)
public class ComplexAnnotations {

    @Qualifier(value = "defaultProductService", required = true)
    private ProductService productService;

    @RequestMapping(
        value = "/{id}",
        method = {RequestMethod.GET, RequestMethod.POST}
    )
    public void getProduct() {
    }
}
